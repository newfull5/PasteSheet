import Foundation
import SQLite3

protocol DirectoryDataSource {
    func fetchAll() throws -> [DirectoryInfoDTO]
    func insert(name: String) throws -> Int64
    func rename(oldName: String, newName: String) throws
    func delete(name: String) throws
}

final class DirectoryDataSourceImpl: DirectoryDataSource {
    private let db = DatabaseManager.shared

    func fetchAll() throws -> [DirectoryInfoDTO] {
        try db.query(
            """
            SELECT d.name, COUNT(p.id) as count
            FROM directories d
            LEFT JOIN paste_sheets p ON d.name = p.directory
            GROUP BY d.name
            ORDER BY CASE WHEN d.name = 'Clipboard' THEN 0 ELSE 1 END, d.created_at
            """,
            mapper: { stmt in
                DirectoryInfoDTO(
                    name: String(cString: sqlite3_column_text(stmt, 0)),
                    count: sqlite3_column_int64(stmt, 1)
                )
            }
        )
    }

    func insert(name: String) throws -> Int64 {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw DirectoryError.emptyName }
        return try db.executeReturningId(
            "INSERT INTO directories (name) VALUES (?1)",
            params: [trimmed]
        )
    }

    func rename(oldName: String, newName: String) throws {
        let oldTrimmed = oldName.trimmingCharacters(in: .whitespaces)
        let newTrimmed = newName.trimmingCharacters(in: .whitespaces)

        guard oldTrimmed != Constants.defaultDirectory,
              newTrimmed != Constants.defaultDirectory,
              !newTrimmed.isEmpty
        else { throw DirectoryError.invalidOperation }

        try db.executeInTransaction {
            try db.execute("PRAGMA foreign_keys = OFF")
            try db.execute(
                "UPDATE directories SET name = ?1 WHERE name = ?2",
                params: [newTrimmed, oldTrimmed]
            )
            try db.execute(
                "UPDATE paste_sheets SET directory = ?1 WHERE directory = ?2",
                params: [newTrimmed, oldTrimmed]
            )
            try db.execute("PRAGMA foreign_keys = ON")
        }
    }

    func delete(name: String) throws {
        guard name != Constants.defaultDirectory else { throw DirectoryError.invalidOperation }
        try db.execute("DELETE FROM paste_sheets WHERE directory = ?1", params: [name])
        try db.execute("DELETE FROM directories WHERE name = ?1", params: [name])
    }
}

enum DirectoryError: Error, LocalizedError {
    case emptyName
    case invalidOperation

    var errorDescription: String? {
        switch self {
        case .emptyName: return "Directory name cannot be empty"
        case .invalidOperation: return "Cannot modify the Clipboard directory"
        }
    }
}
