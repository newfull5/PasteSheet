#![allow(unexpected_cfgs)]
use active_win_pos_rs::get_active_window;
use cocoa::base::{id, nil};
use log::debug;
use objc::{class, msg_send, sel, sel_impl};
use std::ffi::CStr;
use std::sync::Mutex;
use tauri::{AppHandle, Runtime};
use tauri_plugin_global_shortcut::{
    Code, GlobalShortcutExt, Shortcut, ShortcutEvent, ShortcutState,
};
static PREV_APP_NAME: Mutex<Option<String>> = Mutex::new(None);
const DEFAULT_SHORTCUT: &str = "CommandOrControl+Shift+V";
pub fn setup_global_hotkey<R: Runtime>(
    app: AppHandle<R>,
) -> Result<(), Box<dyn std::error::Error>> {
    let shortcut_str = crate::modules::db::get_setting("shortcut")
        .ok()
        .flatten()
        .unwrap_or_else(|| DEFAULT_SHORTCUT.to_string());
    let gs = app.global_shortcut();
    gs.register(shortcut_str.as_str())?;
    Ok(())
}
pub fn update_shortcut<R: Runtime>(
    app: AppHandle<R>,
    new_shortcut: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    let gs = app.global_shortcut();
    gs.unregister_all()?;
    gs.register(new_shortcut)?;
    crate::modules::db::set_setting("shortcut", new_shortcut)?;
    Ok(())
}
fn get_current_app_name() -> Option<String> {
    match get_active_window() {
        Ok(window) => Some(window.app_name),
        Err(_) => None,
    }
}
pub fn save_current_app() {
    if let Some(app_name) = get_current_app_name() {
        if app_name != "PasteSheet" && app_name != "Electron" {
            let mut prev = PREV_APP_NAME.lock().unwrap();
            *prev = Some(app_name.clone());
            debug!("✅ Previous app saved: {}", app_name);
        }
    } else {
        debug!("⚠️ Failed to get current app name");
    }
}
pub fn restore_prev_app_native() {
    #[cfg(target_os = "macos")]
    {
        let prev = PREV_APP_NAME.lock().unwrap();
        if let Some(target_app_name) = &*prev {
            unsafe {
                let workspace_class = class!(NSWorkspace);
                let workspace: id = msg_send![workspace_class, sharedWorkspace];
                let running_apps: id = msg_send![workspace, runningApplications];
                let count: usize = msg_send![running_apps, count];
                for i in 0..count {
                    let app: id = msg_send![running_apps, objectAtIndex: i];
                    let ns_name: id = msg_send![app, localizedName];
                    if ns_name == nil {
                        continue;
                    }
                    let name_ptr: *const i8 = msg_send![ns_name, UTF8String];
                    let name_cstr = CStr::from_ptr(name_ptr);
                    if let Ok(name_str) = name_cstr.to_str() {
                        if name_str == target_app_name {
                            let options: usize = 1 << 1;
                            let _: bool = msg_send![app, activateWithOptions: options];
                            return;
                        }
                    }
                }
            }
        }
    }
}
pub fn handle_shortcut<R: Runtime>(app: &AppHandle<R>, shortcut: &Shortcut, event: ShortcutEvent) {
    if event.state != ShortcutState::Pressed {
        return;
    }
    save_current_app();
    toggle_main_window(app);
}
pub fn toggle_main_window<R: Runtime>(app: &AppHandle<R>) {
    use crate::modules::window_manager;
    window_manager::toggle_main_window(app);
}
