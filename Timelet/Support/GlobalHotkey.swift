import AppKit
import Carbon.HIToolbox

/// Minimal Carbon global-hotkey registration (keeps the build hermetic — no SPM dependency).
/// Used for the global ⌘⇧T check-in shortcut.
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: 0x544C_4554 /* 'TLET' */, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr, let ref {
            refs[id] = ref
            actions[id] = action
        } else {
            NSLog("Timelet: failed to register global hotkey (status \(status))")
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                GlobalHotkeyManager.shared.fire(id: hkID.id)
                return noErr
            },
            1, &spec, nil, nil
        )
    }

    private func fire(id: UInt32) {
        guard let action = actions[id] else { return }
        DispatchQueue.main.async(execute: action)
    }
}
