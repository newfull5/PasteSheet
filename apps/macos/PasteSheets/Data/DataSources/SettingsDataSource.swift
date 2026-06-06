import Foundation
import SQLite3

protocol SettingsDataSource {
    func get(key: String) throws -> String?
    func set(key: String, value: String) throws
}

final class SettingsDataSourceImpl: SettingsDataSource {
    private let db = DatabaseManager.shared

    func get(key: String) throws -> String? {
        try db.queryOne(
            "SELECT value FROM settings WHERE key = ?1",
            params: [key]
        ) { stmt in
            String(cString: sqlite3_column_text(stmt, 0))
        }
    }

    func set(key: String, value: String) throws {
        try db.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
            params: [key, value]
        )
    }
}
