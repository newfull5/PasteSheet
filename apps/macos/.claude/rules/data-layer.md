---
description: SQLite data layer patterns. DatabaseManager usage, raw SQL via SQLite3 C API, DTO mapping, parameterized queries, and CRUD conventions.
globs: apps/macos/**/Data/**/*.swift
---

# Data Layer Rules

## Database Access

### MUST: Use DatabaseManager.shared singleton

All DB access goes through `DatabaseManager.shared`. Never open a second SQLite connection.

```swift
// ✅
final class SomeDataSourceImpl: SomeDataSource {
    private let db = DatabaseManager.shared

    func fetchAll() throws -> [SomeDTO] {
        try db.query("SELECT ...", mapper: Self.mapRow)
    }
}
```

### MUST: Use parameterized queries (prevent SQL injection)

```swift
// ✅ Parameterized — ?1, ?2, etc.
try db.execute(
    "INSERT INTO paste_sheets (content, directory) VALUES (?1, ?2)",
    params: [content, directory]
)

// ❌ NEVER interpolate values into SQL
try db.execute("INSERT INTO paste_sheets (content) VALUES ('\(content)')")
```

## DatabaseManager API

Use these existing methods — do NOT add new execution methods without justification:

| Method | Returns | Use for |
|--------|---------|---------|
| `execute(_:params:)` | `Void` | INSERT, UPDATE, DELETE, DDL |
| `executeReturningId(_:params:)` | `Int64` | INSERT when you need the new row ID |
| `query(_:params:mapper:)` | `[T]` | SELECT returning multiple rows |
| `queryOne(_:params:mapper:)` | `T?` | SELECT returning 0 or 1 row |
| `executeInTransaction(_:)` | `Void` | Multiple operations atomically |

## DTO ↔ Entity Mapping

### MUST: DTO lives in Data layer, Entity in Domain layer

```swift
// Data/DTOs/PasteItemDTO.swift — flat struct matching DB columns
struct PasteItemDTO {
    let id: Int64
    let content: String
    let directory: String
    let createdAt: String
    let memo: String?
}

// Domain/Entities/PasteItem.swift — domain model
struct PasteItem {
    let id: Int64
    let content: String
    let directory: String
    let createdAt: Date
    let memo: String?
}
```

### MUST: Conversion happens in Repository implementation

```swift
// ✅ Repository converts DTO → Entity
final class PasteItemRepositoryImpl: PasteItemRepository {
    func fetchAll(directory: String) throws -> [PasteItem] {
        try dataSource.fetchAll()
            .filter { $0.directory == directory }
            .map { $0.toEntity() }  // DTO → Entity here
    }
}
```

```swift
// ❌ Don't convert in DataSource or ViewModel
```

## Row Mapping

### MUST: Static mapRow method using SQLite3 C API

```swift
// ✅ Pattern used throughout the project
private static func mapRow(_ stmt: OpaquePointer) -> SomeDTO {
    SomeDTO(
        id: sqlite3_column_int64(stmt, 0),
        name: String(cString: sqlite3_column_text(stmt, 1)),
        optional: sqlite3_column_text(stmt, 2).map { String(cString: $0) }
    )
}
```

Column index must match SELECT column order. Use `sqlite3_column_text().map { String(cString:) }` for nullable text columns.

## Schema Changes

### MUST: Add migrations in DatabaseManager.migrateIfNeeded

```swift
// ✅ Check column existence before ALTER
private func migrateIfNeeded() throws {
    let columns = try queryColumnNames(table: "paste_sheets")
    if !columns.contains("new_column") {
        try execute("ALTER TABLE paste_sheets ADD COLUMN new_column TEXT")
    }
}
```

Schema DDL constants go in `DatabaseSchema.swift`.
