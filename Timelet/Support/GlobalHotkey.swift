import AppKit
import Carbon.HIToolbox

/// A key plus Carbon modifier flags, as stored in settings and registered globally.
struct KeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let checkInDefault = KeyCombo(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(controlKey | optionKey))
    static let pauseDefault = KeyCombo(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(controlKey | optionKey))

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// From a key-down event; `nil` when it cannot be a global shortcut
    /// (no ⌘/⌃/⌥ and not a function key — a bare letter would hijack typing).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        let code = UInt32(event.keyCode)
        let isFunctionKey = Self.functionKeys[code] != nil
        guard carbon & UInt32(cmdKey | optionKey | controlKey) != 0 || isFunctionKey else { return nil }
        self.init(keyCode: code, modifiers: carbon)
    }

    /// `⌃⌥T`, in Apple's modifier order.
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + Self.keyName(keyCode)
    }

    /// Shortcuts macOS or every browser already relies on.
    var conflictWarning: String? {
        let cmdShift = UInt32(cmdKey | shiftKey)
        switch (keyCode, modifiers) {
        case (UInt32(kVK_ANSI_T), cmdShift): return "⌘⇧T reopens closed tabs in browsers."
        case (UInt32(kVK_Space), UInt32(cmdKey)): return "⌘Space opens Spotlight."
        case (UInt32(kVK_Tab), UInt32(cmdKey)): return "⌘Tab switches apps."
        case (UInt32(kVK_ANSI_Q), UInt32(cmdKey)), (UInt32(kVK_ANSI_W), UInt32(cmdKey)),
             (UInt32(kVK_ANSI_C), UInt32(cmdKey)), (UInt32(kVK_ANSI_V), UInt32(cmdKey)):
            return "This is a standard editing shortcut in every app."
        default: return nil
        }
    }

    private static let functionKeys: [UInt32: String] = [
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3", UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6", UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9", UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15",
    ]

    private static let specialKeys: [UInt32: String] = [
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥", UInt32(kVK_Escape): "⎋",
        UInt32(kVK_Delete): "⌫", UInt32(kVK_ForwardDelete): "⌦", UInt32(kVK_LeftArrow): "←",
        UInt32(kVK_RightArrow): "→", UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘", UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
    ]

    /// The character the key produces on the current keyboard layout (so AZERTY shows "A" for kVK_ANSI_Q).
    static func keyName(_ code: UInt32) -> String {
        if let f = functionKeys[code] { return f }
        if let s = specialKeys[code] { return s }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return "?" }
            var deadKeys: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return "?" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}

/// Carbon global-hotkey registration (no third-party dependency). Shortcuts are keyed by a
/// stable name so they can be re-registered when the user records a new combo.
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private struct Registration {
        let combo: KeyCombo
        let ref: EventHotKeyRef
        let action: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var ids: [String: UInt32] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false
    /// While the recorder listens, hotkeys are suspended so the current combo can be re-typed.
    private(set) var isSuspended = false

    private init() {}

    /// Registers (or replaces) the shortcut named `name`. Returns false if macOS refused it,
    /// which happens when another app already owns the combo.
    @discardableResult
    func register(_ name: String, combo: KeyCombo?, action: @escaping () -> Void) -> Bool {
        unregister(name)
        guard let combo else { return true }
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: 0x544C_4554 /* 'TLET' */, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            NSLog("Timelet: failed to register \(name) as \(combo.display) (status \(status))")
            return false
        }
        registrations[id] = Registration(combo: combo, ref: ref, action: action)
        ids[name] = id
        return true
    }

    func unregister(_ name: String) {
        guard let id = ids.removeValue(forKey: name), let reg = registrations.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(reg.ref)
    }

    func setSuspended(_ suspended: Bool) { isSuspended = suspended }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                GlobalHotkeyManager.shared.fire(id: hkID.id)
                return noErr
            },
            1, &spec, nil, nil
        )
    }

    private func fire(id: UInt32) {
        guard !isSuspended, let action = registrations[id]?.action else { return }
        DispatchQueue.main.async(execute: action)
    }
}
