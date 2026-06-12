import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class StatusController: NSObject {
    private let statusItem: NSStatusItem
    private let model = UsageModel()
    private var panel: LotusPanel?
    private var clickAwayMonitor: Any?
    private var flagsMonitorLocal: Any?
    private var flagsMonitorGlobal: Any?
    private var optionWasDown = false
    private var moveObserver: NSObjectProtocol?
    private var suppressMoveTracking = false
    private var hotKey: HotKey?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            button.image = Self.glyph(openness: 1)
            button.target = self
            button.action = #selector(statusButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Bua — your Claude session, blooming"
        }
        model.onUpdate = { [weak self] in self?.refreshGlyph() }
        model.startPolling()

        applyHotKey()
    }

    private func applyHotKey() {
        hotKey = nil   // deinit unregisters the old binding
        let defaults = UserDefaults.standard
        let keyCode = defaults.object(forKey: "hotkeyKeyCode") as? UInt32 ?? HotKey.defaultKeyCode
        let modifiers = defaults.object(forKey: "hotkeyModifiers") as? UInt32 ?? HotKey.defaultModifiers
        hotKey = HotKey(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            Task { @MainActor [weak self] in self?.togglePanel() }
        }
    }

    // MARK: Actions

    @objc private func statusButtonClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    @objc private func togglePanelFromMenu() {
        togglePanel()
    }

    @objc private func refreshNow() {
        Task { await model.refresh(force: true) }
    }

    @objc private func togglePin() {
        model.panelPinned.toggle()
    }

    @objc private func toggleDemo() {
        model.demoMode.toggle()
        if model.demoMode, panel?.isVisible != true { showPanel() }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func appearanceSelected(_ sender: NSMenuItem) {
        let choice = AppearanceChoice.allCases[sender.tag]
        AppearanceChoice.current = choice
        panel?.appearance = choice.nsAppearance
    }

    @objc private func editQuotes() {
        Quotes.ensureFileExists()
        NSWorkspace.shared.open(Quotes.fileURL)
    }

    @objc private func changeShortcut() {
        ShortcutRecorder.shared.begin { [weak self] in
            self?.applyHotKey()
        }
    }

    // MARK: Menu

    private func showMenu() {
        let menu = NSMenu()

        let binding = ShortcutRecorder.currentKeyEquivalent
        let toggle = NSMenuItem(title: "Show / Hide Lotus", action: #selector(togglePanelFromMenu), keyEquivalent: binding.key)
        toggle.keyEquivalentModifierMask = binding.modifiers
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let pin = NSMenuItem(
            title: model.panelPinned ? "Unpin Panel" : "Pin Panel",
            action: #selector(togglePin),
            keyEquivalent: "p"
        )
        pin.target = self
        menu.addItem(pin)

        let demo = NSMenuItem(title: "Demo Mode", action: #selector(toggleDemo), keyEquivalent: "d")
        demo.target = self
        demo.state = model.demoMode ? .on : .off
        menu.addItem(demo)

        menu.addItem(.separator())

        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        let appearanceMenu = NSMenu()
        for (index, choice) in AppearanceChoice.allCases.enumerated() {
            let item = NSMenuItem(title: choice.title, action: #selector(appearanceSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = AppearanceChoice.current == choice ? .on : .off
            appearanceMenu.addItem(item)
        }
        appearanceItem.submenu = appearanceMenu
        menu.addItem(appearanceItem)

        let quotes = NSMenuItem(title: "Edit Quotes…", action: #selector(editQuotes), keyEquivalent: "")
        quotes.target = self
        menu.addItem(quotes)

        let shortcut = NSMenuItem(
            title: "Change Shortcut (\(ShortcutRecorder.currentDisplay))…",
            action: #selector(changeShortcut),
            keyEquivalent: ""
        )
        shortcut.target = self
        menu.addItem(shortcut)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Bua", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: Panel

    private func togglePanel() {
        if let panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        model.quote = Quotes.random()
        position(panel)
        panel.orderFrontRegardless()
        model.panelVisible = true
        Task { await model.refresh() }
        installMonitors()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        model.panelVisible = false
        model.demoMode = false
        removeMonitors()
    }

    private func makePanel() -> LotusPanel {
        let size = NSSize(width: PanelContentView.size.width, height: PanelContentView.size.height)
        let hosting = NSHostingView(rootView: PanelContentView(model: model))
        let panel = LotusPanel(contentView: hosting, size: size)
        panel.appearance = AppearanceChoice.current.nsAppearance
        // Remember where Søren drags it (observer fires synchronously on
        // main, so the suppress flag stays valid for programmatic moves)
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: nil
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel,
                      panel.isVisible, !self.suppressMoveTracking else { return }
                let origin = panel.frame.origin
                let defaults = UserDefaults.standard
                defaults.set(origin.x, forKey: "panelOriginX")
                defaults.set(origin.y, forKey: "panelOriginY")
                defaults.set(true, forKey: "panelHasCustomPosition")
            }
        }
        return panel
    }

    private func position(_ panel: LotusPanel) {
        suppressMoveTracking = true
        defer { suppressMoveTracking = false }

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "panelHasCustomPosition") {
            let origin = NSPoint(
                x: defaults.double(forKey: "panelOriginX"),
                y: defaults.double(forKey: "panelOriginY")
            )
            let rect = NSRect(origin: origin, size: panel.frame.size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }

        guard let button = statusItem.button, let window = button.window else { return }
        let buttonRect = window.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size
        var x = buttonRect.midX - size.width / 2
        let y = buttonRect.minY - size.height - 6
        if let screen = window.screen ?? NSScreen.main {
            x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: Event monitors (only while the panel is visible)

    private func installMonitors() {
        removeMonitors()
        clickAwayMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.model.panelPinned else { return }
                self.hidePanel()
            }
        }
        flagsMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let flags = event.modifierFlags
            MainActor.assumeIsolated { self?.handleFlags(flags) }
            return event
        }
        flagsMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let flags = event.modifierFlags
            Task { @MainActor [weak self] in self?.handleFlags(flags) }
        }
    }

    private func removeMonitors() {
        for monitor in [clickAwayMonitor, flagsMonitorLocal, flagsMonitorGlobal] {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        clickAwayMonitor = nil
        flagsMonitorLocal = nil
        flagsMonitorGlobal = nil
        optionWasDown = false
    }

    private func handleFlags(_ flags: NSEvent.ModifierFlags) {
        let down = flags.contains(.option)
        if down && !optionWasDown {
            model.demoMode.toggle()
        }
        optionWasDown = down
    }

    // MARK: Status-bar glyph

    private func refreshGlyph() {
        let openness = model.isResting ? 0.5 : 1 - model.sessionUtilization
        statusItem.button?.image = Self.glyph(openness: openness)
    }

    /// A tiny outlined lotus (stroked, not filled — reads better at 18px),
    /// drawn as a template image so it follows the menu bar's appearance.
    /// Same construction as the panel petals: curved spine from a steep
    /// base tangent, pointed-ellipse width profile. Openness mirrors the
    /// panel lotus.
    static func glyph(openness: Double) -> NSImage {
        let clamped = min(max(openness, 0), 1)
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let base = NSPoint(x: 9, y: 2.5)
            // (bloom tip angle, length): center petal plus two pairs
            let specs: [(Double, Double)] = [(0, 13), (-36, 11), (36, 11), (-70, 8.5), (70, 8.5)]
            let gather = 0.12 + 0.88 * clamped   // closed → angles fold inward

            for (bloomAngle, length) in specs {
                let angle = bloomAngle * gather
                let baseTangent = min(max(angle * 1.5, -94), 94)
                let halfWidth = length * 0.26

                func polar(_ degrees: Double, _ r: Double) -> NSPoint {
                    let rad = degrees * .pi / 180
                    return NSPoint(x: sin(rad) * r, y: cos(rad) * r)   // y-up
                }
                let tipV = polar(angle, length)
                let tip = NSPoint(x: base.x + tipV.x, y: base.y + tipV.y)
                let ctrlV = polar(baseTangent, length * 0.55)
                let ctrl = NSPoint(x: base.x + ctrlV.x, y: base.y + ctrlV.y)

                func spine(_ s: Double) -> NSPoint {
                    let u = 1 - s
                    return NSPoint(
                        x: u * u * base.x + 2 * u * s * ctrl.x + s * s * tip.x,
                        y: u * u * base.y + 2 * u * s * ctrl.y + s * s * tip.y
                    )
                }
                func normal(_ s: Double) -> NSPoint {
                    let u = 1 - s
                    let dx = 2 * u * (ctrl.x - base.x) + 2 * s * (tip.x - ctrl.x)
                    let dy = 2 * u * (ctrl.y - base.y) + 2 * s * (tip.y - ctrl.y)
                    let len = max((dx * dx + dy * dy).squareRoot(), 0.001)
                    return NSPoint(x: -dy / len, y: dx / len)
                }
                func width(_ s: Double) -> Double {
                    halfWidth * pow(sin(.pi * pow(s, 0.85)), 0.9)
                }

                let steps = 14
                var left: [NSPoint] = []
                var right: [NSPoint] = []
                for i in 0...steps {
                    let s = Double(i) / Double(steps)
                    let p = spine(s)
                    let n = normal(s)
                    let w = width(s)
                    left.append(NSPoint(x: p.x + n.x * w, y: p.y + n.y * w))
                    right.append(NSPoint(x: p.x - n.x * w, y: p.y - n.y * w))
                }
                let path = NSBezierPath()
                path.move(to: left[0])
                for p in left.dropFirst() { path.line(to: p) }
                for p in right.reversed() { path.line(to: p) }
                path.close()
                path.lineWidth = 1.1
                path.lineJoinStyle = .round
                NSColor.black.setStroke()
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
