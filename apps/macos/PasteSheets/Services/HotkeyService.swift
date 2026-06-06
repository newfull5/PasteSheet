import Carbon
import AppKit

/// Global hotkey via Carbon `RegisterEventHotKey`.
///
/// This intentionally does NOT use a `CGEvent` tap: a Carbon hot key does not
/// require Accessibility permission, so the toggle shortcut works immediately
/// without the user granting (or re-granting) any privacy permission. This
/// matches how the original Tauri build registered its global shortcut.
final class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?
    private let hotKeyID = EventHotKeyID(signature: 0x5053_5448 /* 'PSTH' */, id: 1)

    func register(shortcut: String, handler: @escaping () -> Void) {
        self.handler = handler
        let (keyCode, modifiers) = Self.parseShortcut(shortcut)
        let msg = "[HotkeyService] Registering (Carbon): \(shortcut) → keyCode=\(keyCode), mods=\(modifiers)\n"
        FileHandle.standardError.write(Data(msg.utf8))

        installEventHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
            FileHandle.standardError.write(Data("[HotkeyService] Hot key registered successfully.\n".utf8))
        } else {
            FileHandle.standardError.write(Data("[HotkeyService] FAILED to register hot key (status=\(status)).\n".utf8))
        }
    }

    func unregisterAll() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        handler = nil
    }

    func updateShortcut(_ newShortcut: String, handler: @escaping () -> Void) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        register(shortcut: newShortcut, handler: handler)
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData, let event else { return noErr }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
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
            if hkID.id == service.hotKeyID.id {
                DispatchQueue.main.async { service.handler?() }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    // MARK: - Parsing

    private static func parseShortcut(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32) {
        var modifiers: UInt32 = 0
        var keyCode: UInt32 = 0

        for part in shortcut.split(separator: "+").map({ String($0) }) {
            switch part {
            case "CommandOrControl", "Command", "Cmd":
                modifiers |= UInt32(cmdKey)
            case "Shift":
                modifiers |= UInt32(shiftKey)
            case "Alt", "Option":
                modifiers |= UInt32(optionKey)
            case "Control", "Ctrl":
                modifiers |= UInt32(controlKey)
            default:
                keyCode = UInt32(Self.keyCodeForCharacter(part.uppercased()))
            }
        }
        return (keyCode, modifiers)
    }

    private static func keyCodeForCharacter(_ char: String) -> UInt16 {
        let map: [String: UInt16] = [
            "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7,
            "C": 8, "V": 9, "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15,
            "Y": 16, "T": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "O": 31, "U": 32,
            "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, "N": 45, "M": 46,
        ]
        return map[char] ?? 0
    }
}
