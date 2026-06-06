---
description: AppKit + SwiftUI integration patterns for PasteSheets. NSPanel (not NSWindow), keyboard routing, NSHostingView bridging, and floating panel behavior.
globs: apps/macos/**/Presentation/**/*.swift,apps/macos/**/App/**/*.swift
---

# AppKit + SwiftUI Integration

## Panel Architecture

### MUST: NSPanel with non-activating style

PasteSheets uses a floating, non-activating panel that must NOT steal focus from the active app.

```swift
// ✅ Correct — this is how MainPanel works
final class MainPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
```

```swift
// ❌ NEVER use NSWindow — it steals focus
class SomePanel: NSWindow { ... }

// ❌ NEVER use .titled or .closable — breaks borderless floating behavior
styleMask: [.titled, .closable, .nonactivatingPanel]
```

### MUST: weak panel reference in ViewModel

```swift
// ✅ ViewModel holds weak ref to avoid retain cycle
weak var panel: NSPanel?
```

### MUST: NSHostingView for SwiftUI bridging

```swift
// ✅ Set SwiftUI content via NSHostingView in AppDelegate
let contentView = ContentView(vm: vm)
panel.contentView = NSHostingView(rootView: contentView)
```

## Keyboard Handling

### MUST: Route keyboard events through MainPanel.sendEvent

PasteSheets intercepts all keyDown events at the panel level, NOT in individual SwiftUI views.

```swift
// ✅ Keyboard routing chain:
// MainPanel.sendEvent → keyDownHandler closure → AppViewModel.handleKeyDown
override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown {
        if let handler = keyDownHandler, handler(event) {
            return  // consumed
        }
    }
    super.sendEvent(event)
}
```

```swift
// ❌ Don't add .onKeyPress or keyboardShortcut in SwiftUI views
// for navigation keys (arrow, enter, escape, tab)
// These are handled centrally in AppViewModel.handleKeyDown
```

### Key routing rules

- **Arrow keys, Enter, Escape, Tab**: Handled in `AppViewModel.handleKeyDown`
- **Cmd+V paste simulation**: Handled via `KeySimulationService.simulatePaste()`
- **Global hotkey (Cmd+Shift+V)**: Handled via `HotkeyService` (CGEvent tap)
- **Text input (search)**: Falls through to SwiftUI TextField via `super.sendEvent`

## Window Lifecycle

### MUST: Hide, don't close

```swift
// ✅ Hide the panel (preserves state)
panel.orderOut(nil)

// ❌ Don't close — it destroys the panel
panel.close()
```

### MUST: Dock hiding via activation policy

```swift
// ✅ App runs as menu bar only — no Dock icon
NSApp.setActivationPolicy(.accessory)
```

## Focus Management

### MUST: Restore previous app focus after paste

After pasting text, PasteSheets must restore focus to the previously active app.
This is handled by `PreviousAppService` — always restore focus before simulating Cmd+V.

```swift
// ✅ Correct sequence
panel.orderOut(nil)                          // 1. hide panel
previousAppService.restoreFocus()            // 2. restore focus
KeySimulationService.simulatePaste()         // 3. simulate Cmd+V
```

```swift
// ❌ Wrong order — paste goes to wrong app
KeySimulationService.simulatePaste()
panel.orderOut(nil)
```
