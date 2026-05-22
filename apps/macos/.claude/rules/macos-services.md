---
description: macOS native service wrapping patterns. NSPasteboard, CGEvent tap, NSScreen, mouse polling, accessibility permissions, and service class design.
globs: apps/macos/**/Services/**/*.swift
---

# macOS Services Rules

## Service Design

### MUST: One service per macOS API domain

Each service wraps exactly one system API. Don't combine unrelated APIs.

| Service | API Domain | Framework |
|---------|-----------|-----------|
| `ClipboardService` | `NSPasteboard.general` | AppKit |
| `HotkeyService` | `CGEvent.tapCreate` | Carbon + CoreGraphics |
| `KeySimulationService` | `CGEvent(keyboardEventSource:)` | CoreGraphics |
| `WindowPositionService` | `NSScreen`, `NSEvent.mouseLocation` | AppKit |
| `MouseEdgeService` | `Timer` + `NSEvent.mouseLocation` | AppKit |
| `PreviousAppService` | `NSWorkspace.shared` | AppKit |
| `AutoStartService` | `SMAppService` | ServiceManagement |

### MUST: Services are plain classes, not protocols

Services wrap system APIs that can't be meaningfully mocked. Keep them as concrete final classes.

```swift
// ✅
final class ClipboardService {
    private let pasteboard = NSPasteboard.general
    func getText() -> String? { ... }
}
```

## CGEvent Tap Pattern (Global Hotkey)

### MUST: Follow the established event tap pattern

```swift
// ✅ Required setup sequence
let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: callback,
    userInfo: Unmanaged.passUnretained(self).toOpaque()
) else { return }

CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
```

### MUST: Check accessibility permission

```swift
// ✅ Always check before creating event tap
AXIsProcessTrustedWithOptions(
    [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
)
```

CGEvent tap and key simulation require Accessibility permission. Without it, the tap silently fails.

### MUST: Clean up on unregister

```swift
// ✅ Remove from run loop and disable tap
CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: false)
```

## Clipboard Monitoring

### MUST: Poll changeCount, don't use notifications

macOS has no reliable clipboard change notification. Use Timer polling:

```swift
// ✅ Poll NSPasteboard.general.changeCount
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    if pasteboard.changeCount != lastChangeCount {
        lastChangeCount = pasteboard.changeCount
        onChange()
    }
}
```

## Mouse / Screen Coordinates

### MUST: Remember macOS coordinate system

macOS uses bottom-left origin (not top-left like iOS).

- `NSEvent.mouseLocation` → screen coordinates, origin at bottom-left
- `NSScreen.main?.frame` → screen bounds
- `NSScreen.main?.visibleFrame` → excludes menu bar and Dock

## Key Simulation

### MUST: Use CGEvent for Cmd+V paste simulation

```swift
// ✅ Simulate Cmd+V
let src = CGEventSource(stateID: .hidSystemState)
let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)   // 9 = V
let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
keyDown?.flags = .maskCommand
keyDown?.post(tap: .cghidEventTap)
keyUp?.post(tap: .cghidEventTap)
```

Virtual key 9 = V. Do NOT use `NSEvent.keyEvent` for this — it doesn't work cross-app.
