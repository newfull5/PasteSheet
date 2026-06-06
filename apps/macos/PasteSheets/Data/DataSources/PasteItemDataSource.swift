import Foundation
import SQLite3

protocol PasteItemDataSource {
    func fetchAll() throws -> [PasteItemDTO]
    func insert(content: String, directory: String, memo: String?) throws -> Int64
    func update(id: Int64, content: String, directory: String, memo: String?) throws
    func delete(id: Int64) throws
    func findByContent(_ content: String, directory: String) throws -> PasteItemDTO?
    func countByDirectory(_ directory: String) throws -> Int64
    func deleteOldest(directory: String, excess: Int64) throws
}

final class PasteItemDataSourceImpl: PasteItemDataSource {
    private let db = DatabaseManager.shared

    func fetchAll() throws -> [PasteItemDTO] {
        try db.query(
            "SELECT id, content, directory, created_at, memo FROM paste_sheets ORDER BY created_at DESC",
            mapper: Self.mapRow
        )
    }

    func insert(content: String, directory: String, memo: String?) throws -> Int64 {
        try db.executeReturningId(
            "INSERT INTO paste_sheets (content, directory, memo) VALUES (?1, ?2, ?3)",
            params: [content, directory, memo]
        )
    }

    func update(id: Int64, content: String, directory: String, memo: String?) throws {
        try db.execute(
            "UPDATE paste_sheets SET content = ?1, directory = ?2, memo = ?3, created_at = CURRENT_TIMESTAMP WHERE id = ?4",
            params: [content, directory, memo, id]
        )
    }

    func delete(id: Int64) throws {
        try db.execute("DELETE FROM paste_sheets WHERE id = ?1", params: [id])
    }

    func findByContent(_ content: String, directory: String) throws -> PasteItemDTO? {
        try db.queryOne(
            "SELECT id, content, directory, created_at, memo FROM paste_sheets WHERE content = ?1 AND directory = ?2 LIMIT 1",
            params: [content, directory],
            mapper: Self.mapRow
        )
    }

    func countByDirectory(_ directory: String) throws -> Int64 {
        let result = try db.queryOne(
            "SELECT COUNT(*) FROM paste_sheets WHERE directory = ?1",
            params: [directory]
        ) { stmt in
            sqlite3_column_int64(stmt, 0)
        }
        return result ?? 0
    }

    func deleteOldest(directory: String, excess: Int64) throws {
        try db.execute(
            """
            DELETE FROM paste_sheets WHERE id IN (
                SELECT id FROM paste_sheets
                WHERE directory = ?1
                ORDER BY created_at ASC
                LIMIT ?2
            )
            """,
            params: [directory, excess]
        )
    }

    private static func mapRow(_ stmt: OpaquePointer) -> PasteItemDTO {
        PasteItemDTO(
            id: sqlite3_column_int64(stmt, 0),
            content: String(cString: sqlite3_column_text(stmt, 1)),
            directory: String(cString: sqlite3_column_text(stmt, 2)),
            createdAt: String(cString: sqlite3_column_text(stmt, 3)),
            memo: sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        )
    }
}
