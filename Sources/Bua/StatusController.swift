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
    }

    // MARK: Actions

    @objc private func statusButtonClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    @objc private func refreshNow() {
        Task { await model.refresh() }
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

    // MARK: Menu

    private func showMenu() {
        let menu = NSMenu()

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
        return LotusPanel(contentView: hosting, size: size)
    }

    private func position(_ panel: LotusPanel) {
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

    /// A tiny five-petal lotus, drawn as a template image so it follows
    /// the menu bar's appearance. Openness mirrors the panel lotus.
    static func glyph(openness: Double) -> NSImage {
        let clamped = min(max(openness, 0), 1)
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let base = NSPoint(x: 9, y: 3.5)
            let spread = 8 + 56 * clamped   // half-fan in degrees
            let petals = 5
            let length = 11.5
            let width = 5.2 * (0.7 + 0.3 * clamped)
            for i in 0..<petals {
                let f = Double(i) / Double(petals - 1)
                let angle = -spread + 2 * spread * f
                let path = NSBezierPath()
                path.move(to: .zero)
                path.curve(
                    to: NSPoint(x: 0, y: length),
                    controlPoint1: NSPoint(x: -width, y: length * 0.30),
                    controlPoint2: NSPoint(x: -width * 0.85, y: length * 0.75)
                )
                path.curve(
                    to: .zero,
                    controlPoint1: NSPoint(x: width * 0.85, y: length * 0.75),
                    controlPoint2: NSPoint(x: width, y: length * 0.30)
                )
                path.close()
                var transform = AffineTransform.identity
                transform.translate(x: base.x, y: base.y)
                transform.rotate(byDegrees: angle)
                path.transform(using: transform)
                NSColor.black.withAlphaComponent(i == petals / 2 ? 1.0 : 0.8).setFill()
                path.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
