namespace PasteSheet.Data.Database;

public static class DatabaseSchema
{
    public const string CreateDirectories = """
        CREATE TABLE IF NOT EXISTS directories (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL UNIQUE,
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """;

    public const string CreatePasteSheets = """
        CREATE TABLE IF NOT EXISTS paste_sheets (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            content     TEXT NOT NULL,
            directory   TEXT NOT NULL,
            memo        TEXT,
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (directory) REFERENCES directories(name)
        )
        """;

    public const string CreateSettings = """
        CREATE TABLE IF NOT EXISTS settings (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """;

    public const string InsertDefaultDirectory = """
        INSERT OR IGNORE INTO directories (name) VALUES ('Clipboard')
        """;

    public const string InsertDefaultMouseEdge = """
        INSERT OR IGNORE INTO settings (key, value) VALUES ('mouse_edge_enabled', 'true')
        """;

    public const string AddMemoColumn = """
        ALTER TABLE paste_sheets ADD COLUMN memo TEXT
        """;

    public const string SyncOrphanDirectories = """
        INSERT OR IGNORE INTO directories (name)
        SELECT DISTINCT directory FROM paste_sheets
        """;
}
