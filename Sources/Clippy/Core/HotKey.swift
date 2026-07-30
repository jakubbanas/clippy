import Carbon.HIToolbox

/// Parses a human hotkey string (`"⌥Space"`, `"cmd shift r"`) into a Carbon
/// key code + modifier mask. Pure and testable; supports modifiers (cmd/opt/
/// ctrl/shift, glyphs or words) plus one key from the a–z / 0–9 / space set.
enum HotKeyCombo {
    static func parse(_ input: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        var s = input.lowercased()
        for (glyph, word) in [("⌘", " cmd "), ("⌥", " option "), ("⌃", " control "), ("⇧", " shift ")] {
            s = s.replacingOccurrences(of: glyph, with: word)
        }
        let tokens = s.split(whereSeparator: { $0 == " " || $0 == "+" || $0 == "-" }).map(String.init)
        guard !tokens.isEmpty else { return nil }

        var modifiers: UInt32 = 0
        var key: String?
        for token in tokens {
            switch token {
            case "cmd", "command": modifiers |= UInt32(cmdKey)
            case "opt", "option", "alt": modifiers |= UInt32(optionKey)
            case "ctrl", "control": modifiers |= UInt32(controlKey)
            case "shift": modifiers |= UInt32(shiftKey)
            default:
                guard key == nil else { return nil } // more than one non-modifier
                key = token
            }
        }
        guard let key, let code = keyCodes[key] else { return nil }
        return (code, modifiers)
    }

    /// Character → Carbon ANSI virtual key code.
    private static let keyCodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32,
        "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        "space": 49,
    ]
}

/// Registers a system-wide hotkey via Carbon `RegisterEventHotKey`, which needs
/// no Accessibility/Input-Monitoring TCC permission — unlike an `NSEvent` global
/// monitor — so it works the moment this `.accessory` app launches. The Carbon
/// event handler runs on the main thread; `onFire` is invoked there.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let callback: () -> Void
    private let id: UInt32
    private static var nextID: UInt32 = 1

    init?(keyCode: UInt32, modifiers: UInt32, onFire: @escaping () -> Void) {
        self.callback = onFire
        self.id = HotKey.nextID
        HotKey.nextID += 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var handler: EventHandlerRef?
        let installed = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else { return noErr }
                var pressedID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &pressedID
                )
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                if pressedID.id == hotKey.id { hotKey.callback() }
                return noErr
            },
            1, &eventType, selfPtr, &handler
        )
        guard installed == noErr else { return nil }
        handlerRef = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950 /* 'CLIP' */), id: id)
        var hotKeyRef: EventHotKeyRef?
        let registered = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef
        )
        guard registered == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
        ref = hotKeyRef
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let handlerRef { RemoveEventHandler(handlerRef); self.handlerRef = nil }
    }

    deinit { unregister() }
}
