use crate::modules::db;
use crate::modules::db::{find_by_content, update_content};
use crate::modules::hotkey::restore_prev_app_native;
use arboard::Clipboard;
use enigo::{
    Direction::{Click, Press, Release},
    Enigo, Key, Keyboard, Settings,
};
use log::{debug, error, info};
use rusqlite::Connection;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
const CLIPBOARD_DEFAULT_DIRECTORY: &str = "Clipboard";
const DEFAULT_MAX_ITEMS: i64 = 50;
const POLLING_INTERVAL: u64 = 100;
pub fn cleanup_old_items(directory: &str) -> Result<(), rusqlite::Error> {
    let max_items = db::get_setting("max_items_per_directory")
        .ok()
        .flatten()
        .and_then(|v| v.parse::<i64>().ok())
        .unwrap_or(DEFAULT_MAX_ITEMS);
    if max_items <= 0 {
        return Ok(());
    }
    let conn = Connection::open(db::get_path())?;
    let count: i64 = conn.query_row(
        "SELECT COUNT(*) FROM paste_sheets WHERE directory = ?1",
        [directory],
        |row| row.get(0),
    )?;
    if count > max_items {
        let excess = count - max_items;
        conn.execute(
            "DELETE FROM paste_sheets WHERE id IN (
                SELECT id FROM paste_sheets
                WHERE directory = ?1
                ORDER BY created_at ASC
                LIMIT ?2
            )",
            rusqlite::params![directory, excess],
        )?;
    }
    Ok(())
}
pub fn get_clipboard_text() -> Option<String> {
    match Clipboard::new() {
        Ok(mut clipboard) => match clipboard.get_text() {
            Ok(text) => Some(text),
            Err(_) => None,
        },
        Err(e) => {
            error!("Failed to create clipboard: {:?}", e);
            None
        }
    }
}
pub fn monitor_clipboard(app_handle: tauri::AppHandle) {
    thread::spawn(move || {
        let last_content = Arc::new(Mutex::new(String::new()));
        info!("Monitoring clipboard...");
        loop {
            thread::sleep(Duration::from_millis(POLLING_INTERVAL));
            if let Some(current_text) = get_clipboard_text() {
                let mut last = last_content.lock().unwrap();
                if current_text != *last && !current_text.trim().is_empty() {
                    info!("Clipboard content changed: {}", current_text.len());
                    let mut changed = false;
                    match find_by_content(&current_text, CLIPBOARD_DEFAULT_DIRECTORY) {
                        Ok(Some(existing_item)) => {
                            info!("Updated existing clipboard content: {:?}", current_text);
                            if let Err(e) = update_content(
                                existing_item.id,
                                &current_text,
                                CLIPBOARD_DEFAULT_DIRECTORY,
                                existing_item.memo.as_deref(),
                            ) {
                                error!("Failed to update content: {:?}", e);
                            } else {
                                changed = true;
                            }
                        }
                        Ok(None) => {
                            if let Err(e) =
                                db::post_content(&current_text, CLIPBOARD_DEFAULT_DIRECTORY, None)
                            {
                                error!("Failed to save to database: {:?}", e);
                            } else {
                                debug!("Saved new content to database");
                                changed = true;
                            }
                            if let Err(e) = cleanup_old_items(CLIPBOARD_DEFAULT_DIRECTORY) {
                                error!("Failed to cleanup old items: {:?}", e);
                            }
                        }
                        Err(e) => {
                            error!("Failed to check content: {:?}", e);
                        }
                    }
                    if changed {
                        use tauri::Emitter;
                        if let Err(e) = app_handle.emit("clipboard-updated", ()) {
                            error!("Failed to emit clipboard-updated event: {:?}", e);
                        }
                    }
                    *last = current_text;
                }
            }
        }
    });
}
pub fn paste_text(text: String) -> Result<(), String> {
    let mut clipboard =
        Clipboard::new().map_err(|e| format!("Failed to create clipboard: {:?}", e))?;
    clipboard
        .set_text(text)
        .map_err(|e| format!("Failed to set clipboard text: {:?}", e))?;
    info!("Text copied to clipbaord");
    restore_prev_app_native();
    let mut enigo = Enigo::new(&Settings::default()).map_err(|e| e.to_string())?;
    #[cfg(target_os = "macos")]
    {
        enigo.key(Key::Meta, Press).map_err(|e| e.to_string())?;
        enigo.raw(9, Click).map_err(|e| e.to_string())?;
        enigo.key(Key::Meta, Release).map_err(|e| e.to_string())?;
    }
    #[cfg(target_os = "windows")]
    {
        enigo.key(Key::Control, Press).map_err(|e| e.to_string())?;
        enigo.raw(86, Click).map_err(|e| e.to_string())?;
        enigo
            .key(Key::Control, Release)
            .map_err(|e| e.to_string())?;
    }
    Ok(())
}
