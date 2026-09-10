import Carbon.HIToolbox
import Foundation

final class HotKeyManager {
    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func start() {
        stop()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            promptBarHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard installStatus == noErr else {
            NSLog("PromptBar: unable to install hot key handler: \(installStatus)")
            return
        }

        let hotKeyID = EventHotKeyID(signature: 0x5155494E, id: 1)
        let modifiers = UInt32(cmdKey | shiftKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            NSLog("PromptBar: unable to register global hot key: \(registerStatus)")
            if let handlerRef {
                RemoveEventHandler(handlerRef)
                self.handlerRef = nil
            }
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    deinit {
        stop()
    }
}

private func promptBarHotKeyHandler(
    _: EventHandlerCallRef?,
    _: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }

    let manager = Unmanaged<HotKeyManager>
        .fromOpaque(userData)
        .takeUnretainedValue()
    manager.onPress?()
    return noErr
}
