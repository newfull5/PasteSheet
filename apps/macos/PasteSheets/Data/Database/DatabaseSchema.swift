import Foundation

enum DatabaseSchema {

    static let createDirectories = """
        CREATE TABLE IF NOT EXISTS directories (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL UNIQUE,
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """

    static let createPasteSheets = """
        CREATE TABLE IF NOT EXISTS paste_sheets (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            content     TEXT NOT NULL,
            directory   TEXT NOT NULL,
            memo        TEXT,
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (directory) REFERENCES directories(name)
        )
        """

    static let createSettings = """
        CREATE TABLE IF NOT EXISTS settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """

    static let insertDefaultDirectory = """
        INSERT OR IGNORE INTO directories (name) VALUES ('Clipboard')
        """

    static let insertDefaultMouseEdge = """
        INSERT OR IGNORE INTO settings (key, value) VALUES ('mouse_edge_enabled', 'true')
        """

    static let addMemoColumn = """
        ALTER TABLE paste_sheets ADD COLUMN memo TEXT
        """

    static let syncOrphanDirectories = """
        INSERT OR IGNORE INTO directories (name)
        SELECT DISTINCT directory FROM paste_sheets
        """
}
