---
description: Swift concurrency and state management rules for macOS 14+ target. Enforces @Observable over ObservableObject, @MainActor over DispatchQueue, async/await over Combine.
globs: apps/macos/**/*.swift
---

# Swift Concurrency & State Management

## Deployment Target: macOS 14+ (Sonoma)

This project is migrating from legacy patterns to modern Swift concurrency.
Apply modern patterns to all new code. When touching existing files, migrate legacy patterns in the same change.

## State Management

### MUST: New ViewModels use @Observable

```swift
// ✅ New code
import Observation

@Observable
final class SomeViewModel {
    var items: [PasteItem] = []
    var isLoading = false
}
```

```swift
// ❌ Never write new code like this
import Combine

final class SomeViewModel: ObservableObject {
    @Published var items: [PasteItem] = []
}
```

### MUST: New Views use @Bindable (not @ObservedObject)

```swift
// ✅ For @Observable classes
struct SomeView: View {
    @Bindable var vm: SomeViewModel
}
```

```swift
// ❌ Legacy — migrate when touching the file
struct SomeView: View {
    @ObservedObject var vm: SomeViewModel
}
```

### Migration rule for existing AppViewModel

AppViewModel currently uses `ObservableObject` + 15 `@Published` properties.
When modifying AppViewModel.swift:
1. Convert class to `@Observable`, remove `ObservableObject` conformance
2. Remove all `@Published` wrappers
3. Remove `import Combine`
4. Update all Views that reference it: `@ObservedObject` → `@Bindable`
5. Do this in one atomic change — no partial migration within the same file

## Threading

### MUST: @MainActor for UI-bound classes

```swift
// ✅ Mark the entire class
@MainActor
@Observable
final class SomeViewModel { ... }
```

### MUST NOT: DispatchQueue.main for UI updates

```swift
// ❌ Legacy
DispatchQueue.main.async { self.doSomething() }
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { ... }

// ✅ Modern
await MainActor.run { self.doSomething() }
try await Task.sleep(for: .milliseconds(500))
```

### MUST NOT: DispatchQueue.global for background work

```swift
// ❌ Legacy
DispatchQueue.global(qos: .userInitiated).async { ... }

// ✅ Modern
Task.detached(priority: .userInitiated) { ... }
```

### Exception: DatabaseManager serial queue

`DatabaseManager.queue` (serial DispatchQueue for SQLite thread safety) is acceptable.
SQLite.swift requires synchronous serial access — do NOT convert this to an actor.

## Async/Await

### MUST: async/await for asynchronous operations

```swift
// ✅
func loadItems() async throws -> [PasteItem] {
    try await repository.fetchAll()
}

// ❌ No completion handlers in new code
func loadItems(completion: @escaping (Result<[PasteItem], Error>) -> Void)
```

### MUST NOT: import Combine in new files

Combine is banned in new code. When migrating existing files, replace:
- `sink` → `async/await` or `AsyncStream`
- `@Published` → plain properties in `@Observable`
- `AnyCancellable` → `Task` handles

## Timer Patterns

For polling (clipboard monitoring, mouse edge detection), `Timer` is acceptable:

```swift
// ✅ Timer for periodic polling is fine
Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in ... }
```
