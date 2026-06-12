import AppKit

/// Borderless, non-activating floating panel — shows the lotus without
/// ever stealing focus from whatever Søren is working in.
final class LotusPanel: NSPanel {
    init(contentView: NSView, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        contentView.frame = NSRect(origin: .zero, size: size)
        self.contentView = contentView
    }

    // Borderless windows refuse key status by default; the demo slider needs it.
    override var canBecomeKey: Bool { true }
}
