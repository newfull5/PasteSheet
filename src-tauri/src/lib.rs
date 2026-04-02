mod modules;
use log::{debug, info};
use modules::clipboard;
use modules::db;
use modules::hotkey;
use modules::window_manager;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::{TrayIconBuilder, TrayIconEvent};
use tauri::AppHandle;
#[tauri::command]
fn get_clipboard_history() -> Result<Vec<db::PasteItem>, String> {
    db::get_all_contents().map_err(|e| e.to_string())
}
#[tauri::command]
fn create_history_item(
    content: String,
    directory: String,
    memo: Option<String>,
) -> Result<i64, String> {
    db::post_content(&content, &directory, memo.as_deref()).map_err(|e| e.to_string())
}
#[tauri::command]
fn paste_text(text: String) -> Result<(), String> {
    clipboard::paste_text(text)
}
#[tauri::command]
fn toggle_main_window(app: AppHandle) {
    hotkey::toggle_main_window(&app);
}
#[tauri::command]
fn get_directories() -> Result<Vec<db::DirectoryInfo>, String> {
    db::get_directories().map_err(|e| e.to_string())
}
#[tauri::command]
fn create_directory(name: String) -> Result<i64, String> {
    db::create_directory(&name).map_err(|e| e.to_string())
}
#[tauri::command]
fn rename_directory(old_name: String, new_name: String) -> Result<(), String> {
    db::rename_directory(&old_name, &new_name).map_err(|e| e.to_string())
}
#[tauri::command]
fn delete_directory(name: String) -> Result<(), String> {
    db::delete_directory(&name).map_err(|e| e.to_string())
}
#[tauri::command]
fn update_history_item(
    id: i64,
    content: String,
    directory: String,
    memo: Option<String>,
) -> Result<(), String> {
    db::update_content(id, &content, &directory, memo.as_deref())
        .map(|_| ())
        .map_err(|e| e.to_string())
}
#[tauri::command]
fn delete_history_item(id: i64) -> Result<(), String> {
    db::delete_history_item(id).map_err(|e| e.to_string())
}
#[tauri::command]
fn get_setting(key: String) -> Result<Option<String>, String> {
    db::get_setting(&key).map_err(|e| e.to_string())
}
#[tauri::command]
fn update_setting(key: String, value: String) -> Result<(), String> {
    db::set_setting(&key, &value).map_err(|e| e.to_string())?;
    if key == "mouse_edge_enabled" {
        window_manager::update_mouse_edge_enabled(value == "true");
    }
    Ok(())
}
#[tauri::command]
fn update_shortcut(app: AppHandle, shortcut: String) -> Result<(), String> {
    hotkey::update_shortcut(app, &shortcut).map_err(|e| e.to_string())
}
#[tauri::command]
fn start_height_resize(window: tauri::WebviewWindow) {
    window_manager::start_height_resize(&window);
}
#[tauri::command]
fn stop_height_resize(window: tauri::WebviewWindow) -> f64 {
    window_manager::stop_height_resize(&window)
}
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(
            tauri_plugin_global_shortcut::Builder::new()
                .with_handler(hotkey::handle_shortcut)
                .build(),
        )
        .on_window_event(|window, event| match event {
            tauri::WindowEvent::CloseRequested { api, .. } => {
                let _ = window.hide();
                window_manager::set_window_state(false);
                api.prevent_close();
            }
            _ => {}
        })
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Debug)
                        .build(),
                )?;
            }
            hotkey::save_current_app();
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);
            let _conn = db::init_db().expect("Failed to initialize database");
            info!("Database initialized");
            if let Ok(Some(val)) = db::get_setting("mouse_edge_enabled") {
                window_manager::update_mouse_edge_enabled(val == "true");
            }
            let db_path = db::get_path();
            debug!("Database path: {:?}", db_path);
            let quit_i = MenuItem::with_id(app, "quit", "Quit PasteSheet", true, None::<&str>)?;
            let show_i = MenuItem::with_id(app, "show", "Show App", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_i, &quit_i])?;
            #[cfg(target_os = "macos")]
            let tray_icon = {
                let scale_factor = app
                    .primary_monitor()
                    .ok()
                    .flatten()
                    .map(|m| m.scale_factor())
                    .unwrap_or(2.0); 
                debug!("Display scale factor: {}", scale_factor);
                let icon_bytes: &[u8] = if scale_factor >= 2.0 {
                    include_bytes!("../icons/iconTemplate@2x.png")
                } else {
                    include_bytes!("../icons/iconTemplate.png")
                };
                let img = image::load_from_memory(icon_bytes)
                    .expect("Failed to load tray icon")
                    .to_rgba8();
                let (width, height) = img.dimensions();
                let rgba = img.into_raw();
                tauri::image::Image::new_owned(rgba, width, height)
            };
            #[cfg(not(target_os = "macos"))]
            let tray_icon = app.default_window_icon().unwrap().clone();
            #[cfg(target_os = "macos")]
            let _tray = TrayIconBuilder::new()
                .icon(tray_icon)
                .icon_as_template(true)
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => {
                        app.exit(0);
                    }
                    "show" => {
                        window_manager::toggle_main_window(app);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: tauri::tray::MouseButton::Left,
                        button_state: tauri::tray::MouseButtonState::Down,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        window_manager::toggle_main_window(app);
                    }
                })
                .build(app)?;
            #[cfg(not(target_os = "macos"))]
            let _tray = TrayIconBuilder::new()
                .icon(tray_icon)
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => {
                        app.exit(0);
                    }
                    "show" => {
                        window_manager::toggle_main_window(app);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: tauri::tray::MouseButton::Left,
                        button_state: tauri::tray::MouseButtonState::Down,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        window_manager::toggle_main_window(app);
                    }
                })
                .build(app)?;
            clipboard::monitor_clipboard(app.handle().clone());
            info!("Clipboard monitoring started");
            hotkey::setup_global_hotkey(app.handle().clone())?;
            info!("Global hotkey setup completed");
            window_manager::start_mouse_edge_monitor(app.handle().clone())?;
            info!("Mouse edge detection started");
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_clipboard_history,
            get_directories,
            create_directory,
            rename_directory,
            delete_directory,
            paste_text,
            toggle_main_window,
            update_history_item,
            delete_history_item,
            create_history_item,
            get_setting,
            update_setting,
            start_height_resize,
            stop_height_resize,
            update_shortcut
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
