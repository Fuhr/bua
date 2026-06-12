import Carbon.HIToolbox
import Foundation

/// A system-wide hotkey via Carbon's RegisterEventHotKey — the one API
/// that works globally without accessibility permissions. Default is
/// ⌃⌥B ("B for Bua"); override with
///   defaults write com.sorenfuhr.bua hotkeyKeyCode -int <code>
///   defaults write com.sorenfuhr.bua hotkeyModifiers -int <carbon mask>
final class HotKey {
    static let defaultKeyCode = UInt32(kVK_ANSI_B)
    static let defaultModifiers = UInt32(controlKey | optionKey)

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let callback: @Sendable () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, callback: @escaping @Sendable () -> Void) {
        self.callback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().fire()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard status == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x42554121), id: 1)   // 'BUA!'
        guard RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        ) == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    private func fire() {
        callback()
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
