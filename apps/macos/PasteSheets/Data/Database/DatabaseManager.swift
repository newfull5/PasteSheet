import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.pastesheets.db", qos: .userInitiated)

    private init() {}

    var databasePath: String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("paste_sheets.db").path
    }

    func initialize() throws {
        let dir = (databasePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        guard sqlite3_open(databasePath, &db) == SQLITE_OK else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
        }

        try execute(DatabaseSchema.createDirectories)
        try execute(DatabaseSchema.createPasteSheets)
        try execute(DatabaseSchema.createSettings)
        try execute(DatabaseSchema.insertDefaultDirectory)
        try execute(DatabaseSchema.insertDefaultMouseEdge)
        try migrateIfNeeded()
        try execute(DatabaseSchema.syncOrphanDirectories)
    }

    private func migrateIfNeeded() throws {
        let columns = try queryColumnNames(table: "paste_sheets")
        if !columns.contains("memo") {
            try execute(DatabaseSchema.addMemoColumn)
        }
    }

    private func queryColumnNames(table: String) throws -> [String] {
        var stmt: OpaquePointer?
        let sql = "PRAGMA table_info(\(table))"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        var names: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cStr = sqlite3_column_text(stmt, 1) {
                names.append(String(cString: cStr))
            }
        }
        return names
    }

    // MARK: - Execution Helpers

    func execute(_ sql: String, params: [Any?] = []) throws {
        try queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            try bindParams(stmt: stmt, params: params)

            let result = sqlite3_step(stmt)
            guard result == SQLITE_DONE || result == SQLITE_ROW else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    func executeReturningId(_ sql: String, params: [Any?] = []) throws -> Int64 {
        try queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            try bindParams(stmt: stmt, params: params)

            guard sqlite3_step(stmt) == SQLITE_DONE else {
                throw DatabaseError.executionFailed(String(cString: sqlite3_errmsg(db)))
            }
            return sqlite3_last_insert_rowid(db)
        }
    }

    func query<T>(_ sql: String, params: [Any?] = [], mapper: (OpaquePointer) -> T) throws -> [T] {
        try queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
            }
            defer { sqlite3_finalize(stmt) }

            try bindParams(stmt: stmt, params: params)

            var results: [T] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(mapper(stmt!))
            }
            return results
        }
    }

    func queryOne<T>(_ sql: String, params: [Any?] = [], mapper: (OpaquePointer) -> T) throws -> T? {
        let results = try query(sql, params: params, mapper: mapper)
        return results.first
    }

    func executeInTransaction(_ block: () throws -> Void) throws {
        try execute("BEGIN TRANSACTION")
        do {
            try block()
            try execute("COMMIT")
        } catch {
            try execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Bind

    private func bindParams(stmt: OpaquePointer?, params: [Any?]) throws {
        for (index, param) in params.enumerated() {
            let i = Int32(index + 1)
            switch param {
            case nil:
                sqlite3_bind_null(stmt, i)
            case let val as String:
                sqlite3_bind_text(stmt, i, (val as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let val as Int64:
                sqlite3_bind_int64(stmt, i, val)
            case let val as Int:
                sqlite3_bind_int64(stmt, i, Int64(val))
            case let val as Double:
                sqlite3_bind_double(stmt, i, val)
            default:
                sqlite3_bind_text(stmt, i, ("\(param!)" as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        }
    }
}

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg): return "DB open failed: \(msg)"
        case .prepareFailed(let msg): return "SQL prepare failed: \(msg)"
        case .executionFailed(let msg): return "SQL execution failed: \(msg)"
        }
    }
}
