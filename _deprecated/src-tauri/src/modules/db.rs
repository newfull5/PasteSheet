use rusqlite::{Connection, Result};
#[derive(serde::Serialize, serde::Deserialize)]
pub struct DirectoryInfo {
    pub name: String,
    pub count: i64,
}
#[derive(serde::Serialize, serde::Deserialize)]
pub struct PasteItem {
    pub id: i64,
    pub content: String,
    pub directory: String,
    pub created_at: String,
    pub memo: Option<String>,
}
pub fn get_directories() -> Result<Vec<DirectoryInfo>> {
    let conn = Connection::open(get_path())?;
    let mut stmt = conn.prepare(
        "SELECT d.name, COUNT(p.id) as count
         FROM directories d
         LEFT JOIN paste_sheets p ON d.name = p.directory
         GROUP BY d.name
         ORDER BY CASE WHEN d.name = 'Clipboard' THEN 0 ELSE 1 END, d.created_at",
    )?;
    let rows = stmt.query_map([], |row| {
        Ok(DirectoryInfo {
            name: row.get(0)?,
            count: row.get(1)?,
        })
    })?;
    let mut result = Vec::new();
    for row in rows {
        result.push(row?);
    }
    Ok(result)
}
pub fn get_path() -> String {
    let mut path = dirs::data_dir().unwrap();
    path.push("paste_sheets.db");
    path.to_str().unwrap().to_string()
}
pub fn init_db() -> Result<Connection> {
    let conn = Connection::open(get_path())?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS directories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )",
        [],
    )?;
    conn.execute(
        "INSERT OR IGNORE INTO directories (name) VALUES ('Clipboard')",
        [],
    )?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS paste_sheets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            directory TEXT NOT NULL,
            memo TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (directory) REFERENCES directories(name)
        )",
        [],
    )?;
    let has_memo = {
        let mut stmt = conn.prepare("PRAGMA table_info(paste_sheets)")?;
        let rows = stmt.query_map([], |row| {
            let name: String = row.get(1)?;
            Ok(name)
        })?;
        let mut found = false;
        for row in rows {
            if let Ok(name) = row {
                if name == "memo" {
                    found = true;
                    break;
                }
            }
        }
        found
    };
    if !has_memo {
        conn.execute("ALTER TABLE paste_sheets ADD COLUMN memo TEXT", [])?;
    }
    conn.execute(
        "INSERT OR IGNORE INTO directories (name)
         SELECT DISTINCT directory FROM paste_sheets",
        [],
    )?;
    conn.execute(
        "CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )",
        [],
    )?;
    conn.execute(
        "INSERT OR IGNORE INTO settings (key, value) VALUES ('mouse_edge_enabled', 'true')",
        [],
    )?;
    Ok(conn)
}
pub fn create_directory(name: &str) -> Result<i64> {
    let trimmed_name = name.trim();
    if trimmed_name.is_empty() {
        return Err(rusqlite::Error::InvalidQuery);
    }
    let conn = Connection::open(get_path())?;
    conn.execute("INSERT INTO directories (name) VALUES (?1)", [trimmed_name])?;
    Ok(conn.last_insert_rowid())
}
pub fn rename_directory(old_name: &str, new_name: &str) -> Result<()> {
    let old_trimmed = old_name.trim();
    let new_trimmed = new_name.trim();
    if old_trimmed == "Clipboard" || new_trimmed == "Clipboard" || new_trimmed.is_empty() {
        return Err(rusqlite::Error::InvalidQuery);
    }
    log::info!("[DB] Rename start: '{}' -> '{}'", old_trimmed, new_trimmed);
    let mut conn = Connection::open(get_path())?;
    conn.execute("PRAGMA foreign_keys = OFF", [])?;
    let tx = conn.transaction()?;
    let affected_dirs = tx.execute(
        "UPDATE directories SET name = ?1 WHERE name = ?2",
        [new_trimmed, old_trimmed],
    )?;
    log::info!("[DB] Affected directories: {}", affected_dirs);
    if affected_dirs == 0 {
        return Err(rusqlite::Error::QueryReturnedNoRows);
    }
    let affected_items = tx.execute(
        "UPDATE paste_sheets SET directory = ?1 WHERE directory = ?2",
        [new_trimmed, old_trimmed],
    )?;
    log::info!("[DB] Affected paste items: {}", affected_items);
    tx.commit()?;
    conn.execute("PRAGMA foreign_keys = ON", [])?;
    log::info!("[DB] Rename committed successfully");
    Ok(())
}
pub fn delete_directory(name: &str) -> Result<()> {
    if name == "Clipboard" {
        return Err(rusqlite::Error::InvalidQuery);
    }
    let conn = Connection::open(get_path())?;
    conn.execute("DELETE FROM paste_sheets WHERE directory = ?1", [name])?;
    conn.execute("DELETE FROM directories WHERE name = ?1", [name])?;
    Ok(())
}
pub fn post_content(content: &str, directory: &str, memo: Option<&str>) -> Result<i64> {
    let conn = Connection::open(get_path())?;
    conn.execute(
        "INSERT INTO paste_sheets (content, directory, memo) VALUES (?1, ?2, ?3)",
        rusqlite::params![content, directory, memo],
    )?;
    Ok(conn.last_insert_rowid())
}
pub fn get_all_contents() -> Result<Vec<PasteItem>> {
    let conn = Connection::open(get_path())?;
    let mut stmt = conn.prepare(
        "SELECT id, content, directory, created_at, memo FROM paste_sheets ORDER BY created_at DESC",
    )?;
    let rows = stmt.query_map([], |row| {
        Ok(PasteItem {
            id: row.get(0)?,
            content: row.get(1)?,
            directory: row.get(2)?,
            created_at: row.get(3)?,
            memo: row.get(4)?,
        })
    })?;
    let mut result = Vec::new();
    for row in rows {
        result.push(row?);
    }
    Ok(result)
}
pub fn update_content(id: i64, content: &str, directory: &str, memo: Option<&str>) -> Result<i64> {
    let conn = Connection::open(get_path())?;
    conn.execute(
        "UPDATE paste_sheets SET content = ?1, directory = ?2, memo = ?3, created_at = CURRENT_TIMESTAMP WHERE id = ?4",
        rusqlite::params![content, directory, memo, id],
    )?;
    Ok(id)
}
pub fn find_by_content(content: &str, directory: &str) -> Result<Option<PasteItem>> {
    let conn = Connection::open(get_path())?;
    let mut stmt = conn.prepare(
        "SELECT id, content, directory, created_at, memo FROM paste_sheets WHERE content = ?1 AND directory = ?2 LIMIT 1",
    )?;
    let result = stmt.query_row([content, directory], |row| {
        Ok(PasteItem {
            id: row.get(0)?,
            content: row.get(1)?,
            directory: row.get(2)?,
            created_at: row.get(3)?,
            memo: row.get(4)?,
        })
    });
    match result {
        Ok(item) => Ok(Some(item)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
}
pub fn delete_history_item(id: i64) -> Result<()> {
    let conn = Connection::open(get_path())?;
    conn.execute("DELETE FROM paste_sheets WHERE id = ?1", [id])?;
    Ok(())
}
pub fn get_setting(key: &str) -> Result<Option<String>> {
    let conn = Connection::open(get_path())?;
    let mut stmt = conn.prepare("SELECT value FROM settings WHERE key = ?1")?;
    let result = stmt.query_row([key], |row| row.get(0));
    match result {
        Ok(val) => Ok(Some(val)),
        Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
        Err(e) => Err(e),
    }
}
pub fn set_setting(key: &str, value: &str) -> Result<()> {
    let conn = Connection::open(get_path())?;
    conn.execute(
        "INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)",
        [key, value],
    )?;
    Ok(())
}
