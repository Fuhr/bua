import AppKit
import Carbon.HIToolbox

/// A tiny "press the new shortcut" window. Saves keyCode + carbon
/// modifiers (+ display string and key char for the menu) to
/// UserDefaults; the StatusController re-registers the hotkey on save.
@MainActor
final class ShortcutRecorder {
    static let shared = ShortcutRecorder()

    private var panel: NSPanel?
    private var onChange: (() -> Void)?

    static var currentDisplay: String {
        UserDefaults.standard.string(forKey: "hotkeyDisplay") ?? "⌃⌥B"
    }

    /// For showing the live binding as a menu key equivalent.
    static var currentKeyEquivalent: (key: String, modifiers: NSEvent.ModifierFlags) {
        let defaults = UserDefaults.standard
        let key = defaults.string(forKey: "hotkeyKeyChar") ?? "b"
        let carbon = defaults.object(forKey: "hotkeyModifiers") as? UInt32 ?? HotKey.defaultModifiers
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbon & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbon & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        return (key, flags)
    }

    func begin(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let view = RecorderView(frame: NSRect(x: 0, y: 0, width: 320, height: 110))
        view.recorder = self
        let panel = NSPanel(
            contentRect: view.frame,
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Bua Shortcut"
        panel.contentView = view
        panel.level = .floating
        panel.center()
        panel.isReleasedWhenClosed = false
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
    }

    func save(keyCode: UInt32, modifiers: UInt32, display: String, keyChar: String) {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: "hotkeyKeyCode")
        defaults.set(Int(modifiers), forKey: "hotkeyModifiers")
        defaults.set(display, forKey: "hotkeyDisplay")
        defaults.set(keyChar, forKey: "hotkeyKeyChar")
        close(changed: true)
    }

    func reset() {
        let defaults = UserDefaults.standard
        for key in ["hotkeyKeyCode", "hotkeyModifiers", "hotkeyDisplay", "hotkeyKeyChar"] {
            defaults.removeObject(forKey: key)
        }
        close(changed: true)
    }

    func cancel() {
        close(changed: false)
    }

    private func close(changed: Bool) {
        panel?.close()
        panel = nil
        if changed { onChange?() }
        onChange = nil
    }
}

private final class RecorderView: NSView {
    weak var recorder: ShortcutRecorder?

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        let title = NSTextField(labelWithString: "Press the new shortcut")
        title.font = .systemFont(ofSize: 15, weight: .medium)
        title.alignment = .center
        title.frame = NSRect(x: 0, y: 60, width: 320, height: 24)
        addSubview(title)

        let hint = NSTextField(labelWithString: "include ⌃, ⌥ or ⌘  ·  esc cancels  ·  ⌫ resets to ⌃⌥B")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.frame = NSRect(x: 0, y: 32, width: 320, height: 16)
        addSubview(hint)
    }

    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])

        if event.keyCode == UInt16(kVK_Escape) {
            recorder?.cancel()
            return
        }
        if event.keyCode == UInt16(kVK_Delete) && flags.isEmpty {
            recorder?.reset()
            return
        }
        // Require a real chord — plain letters would hijack typing everywhere
        guard !flags.intersection([.command, .control, .option]).isEmpty else {
            NSSound.beep()
            return
        }

        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }

        let keyChar = event.charactersIgnoringModifiers?.lowercased() ?? ""
        recorder?.save(
            keyCode: UInt32(event.keyCode),
            modifiers: carbon,
            display: Self.display(flags: flags, event: event),
            keyChar: keyChar
        )
    }

    private static func display(flags: NSEvent.ModifierFlags, event: NSEvent) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        let special: [UInt16: String] = [
            UInt16(kVK_Space): "Space",
            UInt16(kVK_Return): "↩",
            UInt16(kVK_Tab): "⇥",
            UInt16(kVK_LeftArrow): "←",
            UInt16(kVK_RightArrow): "→",
            UInt16(kVK_UpArrow): "↑",
            UInt16(kVK_DownArrow): "↓",
        ]
        if let name = special[event.keyCode] {
            return s + name
        }
        return s + (event.charactersIgnoringModifiers?.uppercased() ?? "?")
    }
}
