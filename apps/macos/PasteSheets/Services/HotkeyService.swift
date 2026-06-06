import Carbon
import AppKit

final class HotkeyService {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: (() -> Void)?
    private var registeredKeyCode: UInt16 = 0
    private var registeredModifiers: CGEventFlags = []

    func register(shortcut: String, handler: @escaping () -> Void) {
        self.handler = handler
        parseShortcut(shortcut)
        let msg = "[HotkeyService] Registering shortcut: \(shortcut) → keyCode=\(registeredKeyCode), mods=\(registeredModifiers.rawValue)\n"
        FileHandle.standardError.write(Data(msg.utf8))
        installEventTap()
    }

    func unregisterAll() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        handler = nil
    }

    func updateShortcut(_ newShortcut: String, handler: @escaping () -> Void) {
        unregisterAll()
        register(shortcut: newShortcut, handler: handler)
    }

    private func parseShortcut(_ shortcut: String) {
        let parts = shortcut.split(separator: "+").map { String($0) }
        var flags: CGEventFlags = []
        var keyCode: UInt16 = 0

        for part in parts {
            switch part {
            case "CommandOrControl", "Command", "Cmd":
                flags.insert(.maskCommand)
            case "Shift":
                flags.insert(.maskShift)
            case "Alt", "Option":
                flags.insert(.maskAlternate)
            case "Control", "Ctrl":
                flags.insert(.maskControl)
            default:
                keyCode = Self.keyCodeForCharacter(part.uppercased())
            }
        }
        registeredKeyCode = keyCode
        registeredModifiers = flags
    }

    private func installEventTap() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        do {
            let m1 = "[HotkeyService] AXIsProcessTrusted: \(trusted)\n"
            FileHandle.standardError.write(Data(m1.utf8))
        }
        if !trusted {
            let m2 = "[HotkeyService] Accessibility NOT granted.\n"
            FileHandle.standardError.write(Data(m2.utf8))
        }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let service = Unmanaged<HotkeyService>.fromOpaque(refcon!).takeUnretainedValue()
            return service.handleEvent(proxy: proxy, type: type, event: event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            let m3 = "[HotkeyService] FAILED to create event tap.\n"
            FileHandle.standardError.write(Data(m3.utf8))
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        let m4 = "[HotkeyService] Event tap created and enabled successfully.\n"
        FileHandle.standardError.write(Data(m4.utf8))
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            let m = "[HotkeyService] Event tap was DISABLED, re-enabling...\n"
            FileHandle.standardError.write(Data(m.utf8))
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passRetained(event)
        }
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        let relevantFlags: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        let pressedMods = flags.intersection(relevantFlags)
        let requiredMods = registeredModifiers.intersection(relevantFlags)

        if keyCode == registeredKeyCode && pressedMods == requiredMods {
            DispatchQueue.main.async { [weak self] in
                self?.handler?()
            }
            return nil
        }
        return Unmanaged.passRetained(event)
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
