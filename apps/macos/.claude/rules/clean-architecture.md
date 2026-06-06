---
description: Clean Architecture layer dependency rules. Enforces Data → Domain → Presentation direction, import restrictions per layer, and protocol-based design.
globs: apps/macos/**/*.swift
---

# Clean Architecture Rules

## Layer Dependency Direction

```
Presentation (Views, ViewModels)
     ↓ depends on
Domain (Entities, UseCases, Repository protocols)
     ↑ implements
Data (DataSources, DTOs, DatabaseManager)
```

Dependencies flow downward only. Domain is the innermost layer with zero framework dependencies.

## Import Restrictions

### Domain layer (`Domain/**`)

MUST only import `Foundation`. Nothing else.

```swift
// ✅
import Foundation

// ❌ NEVER in Domain
import AppKit
import SwiftUI
import Observation
import SQLite  // belongs in Data layer
```

### Data layer (`Data/**`)

MUST only import `Foundation` and database libraries (`SQLite`, `GRDB`).

```swift
// ❌ NEVER in Data layer
import AppKit
import SwiftUI
```

### Services layer (`Services/**`)

MAY import `AppKit`, `Carbon`, `CoreGraphics` — this is the only layer that wraps macOS native APIs.

### Presentation layer (`Presentation/**`)

MAY import `SwiftUI`, `AppKit` (for NSEvent, NSPanel types), `Observation`.

## Dependency Rules

### MUST: ViewModel depends on UseCases only

```swift
// ✅ ViewModel receives UseCases via init
final class AppViewModel {
    let manageItems: ManageItemsUseCase
    let searchUseCase: SearchUseCase
}
```

```swift
// ❌ ViewModel must NEVER access DataSource or Repository directly
final class AppViewModel {
    let dataSource: PasteItemDataSource  // violation
    let db: DatabaseManager              // violation
}
```

### MUST: Protocol-based DataSource and Repository

```swift
// ✅ Domain defines protocol
protocol PasteItemRepository {
    func fetchAll(directory: String) throws -> [PasteItem]
}

// ✅ Data layer implements it
final class PasteItemRepositoryImpl: PasteItemRepository { ... }
```

### MUST: UseCase wraps a single business operation

```swift
// ✅ Focused use case
final class SearchUseCase {
    private let repository: PasteItemRepository
    func search(query: String, directory: String) throws -> [PasteItem] { ... }
}
```

```swift
// ❌ God use case doing everything
final class EverythingUseCase {
    func search() { ... }
    func delete() { ... }
    func export() { ... }
    func changeSettings() { ... }
}
```

## Error Handling

### MUST: throws for error propagation, catch at Presentation layer

```swift
// ✅ Domain/Data: throw errors up
func save(item: PasteItem) throws { ... }

// ✅ Presentation: catch and handle
func onSave() {
    do {
        try manageItems.save(item)
    } catch {
        // show error to user
    }
}
```

## File Placement

| Type | Directory | Naming |
|------|-----------|--------|
| Entity | `Domain/Entities/` | `PasteItem.swift` |
| Repository protocol | `Domain/Repositories/` | `PasteItemRepository.swift` |
| UseCase | `Domain/UseCases/` | `ManageItemsUseCase.swift` |
| DTO | `Data/DTOs/` | `PasteItemDTO.swift` |
| DataSource | `Data/DataSources/` | `PasteItemDataSource.swift` |
| Database | `Data/Database/` | `DatabaseManager.swift` |
| Service | `Services/` | `ClipboardService.swift` |
| ViewModel | `Presentation/ViewModels/` | `AppViewModel.swift` |
| View | `Presentation/Views/` | `ContentView.swift` |
| Component | `Presentation/Components/` | `HeaderView.swift` |
