import Foundation
import Carbon

final class HotKeyManager {
    var onToggle: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init() {
        // Install a handler for hotkey pressed events
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            var hkCom = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkCom)
            let id = hkCom.id
            if id == 1 {
                DispatchQueue.main.async {
                    AppController.shared.togglePanel()
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandler)
    }

    func registerDefaultHotKey() {
        unregisterHotKey()

        // Command + Shift + .
        let modifiers: UInt32 = (UInt32(cmdKey) | UInt32(shiftKey))
        let keyCode: UInt32 = UInt32(kVK_ANSI_Period)

        let hotKeyID = EventHotKeyID(signature: UTGetOSTypeFromString("RBHK") ?? 0, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregisterHotKey() {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
            hotKeyRef = nil
        }
    }

    deinit {
        unregisterHotKey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

// Helper to convert a 4-char string to OSType
func UTGetOSTypeFromString(_ str: String) -> OSType? {
    guard str.utf8.count == 4 else { return nil }
    var result: OSType = 0
    for byte in str.utf8 {
        result = (result << 8) + OSType(byte)
    }
    return result
}
