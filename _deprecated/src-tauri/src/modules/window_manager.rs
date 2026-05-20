#![allow(unexpected_cfgs)]
use log::debug;
use std::sync::Mutex;
use tauri::{AppHandle, Emitter, LogicalPosition, Manager, Runtime};
#[cfg(target_os = "macos")]
use objc::{class, msg_send, sel, sel_impl};
static IS_WINDOW_VISIBLE: Mutex<bool> = Mutex::new(false);
static IS_AUTO_HIDE_ENABLED: Mutex<bool> = Mutex::new(false);
static MOUSE_EDGE_ENABLED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(true);
static IS_HEIGHT_RESIZING: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);
static RESIZE_START_MOUSE_Y: Mutex<f64> = Mutex::new(0.0);
static RESIZE_START_HEIGHT: Mutex<f64> = Mutex::new(0.0);
pub fn set_window_state(is_visible: bool) {
    if let Ok(mut visible) = IS_WINDOW_VISIBLE.lock() {
        *visible = is_visible;
    }
}
pub fn toggle_main_window<R: Runtime>(app: &AppHandle<R>) {
    if let Some(window) = app.get_webview_window("main") {
        let mut visible = IS_WINDOW_VISIBLE.lock().unwrap();
        let mut auto_hide = IS_AUTO_HIDE_ENABLED.lock().unwrap();
        if *visible {
            *visible = false;
            *auto_hide = false;
            let _ = window.emit("window-visible", false);
            let window_clone = window.clone();
            std::thread::spawn(move || {
                std::thread::sleep(std::time::Duration::from_millis(350));
                let still_hidden = {
                    let s = IS_WINDOW_VISIBLE.lock().unwrap();
                    !*s
                };
                if still_hidden {
                    let _ = window_clone.hide();
                    debug!("Window physically hidden after animation delay");
                }
            });
        } else {
            *visible = true;
            *auto_hide = false;
            #[cfg(target_os = "macos")]
            if let Some(screen) = get_active_screen_info() {
                let window_width = window
                    .inner_size()
                    .ok()
                    .map(|s| {
                        let scale = window
                            .current_monitor()
                            .ok()
                            .flatten()
                            .map(|m| m.scale_factor())
                            .unwrap_or(2.0);
                        s.width as f64 / scale
                    })
                    .unwrap_or(410.0);
                let x = screen.x + screen.width - window_width;
                let y = screen.y;
                let _ = window.set_position(LogicalPosition::new(x, y));
                debug!("✅ Window repositioned to active monitor: ({}, {})", x, y);
            }
            let _ = window.show();
            let _ = window.set_focus();
            let window_clone = window.clone();
            std::thread::spawn(move || {
                std::thread::sleep(std::time::Duration::from_millis(20));
                let _ = window_clone.emit("window-visible", true);
            });
            debug!("Window shown and animation-start emitted");
        }
    }
}
pub fn start_mouse_edge_monitor<R: Runtime>(
    app: AppHandle<R>,
) -> Result<(), Box<dyn std::error::Error>> {
    set_window_position(&app);
    #[cfg(target_os = "macos")]
    {
        let app_clone = app.clone();
        std::thread::spawn(move || {
            setup_mouse_event_monitoring(app_clone);
        });
    }
    Ok(())
}
fn set_window_position<R: Runtime>(app: &AppHandle<R>) {
    std::thread::sleep(std::time::Duration::from_millis(100));
    if let Some(window) = app.get_webview_window("main") {
        #[cfg(target_os = "macos")]
        if let Some(screen) = get_active_screen_info() {
            let window_width = window
                .inner_size()
                .ok()
                .map(|s| {
                    let scale = window
                        .current_monitor()
                        .ok()
                        .flatten()
                        .map(|m| m.scale_factor())
                        .unwrap_or(2.0);
                    s.width as f64 / scale
                })
                .unwrap_or(410.0);
            let x = screen.x + screen.width - window_width;
            let y = screen.y;
            let _ = window.set_position(LogicalPosition::new(x, y));
            debug!("✅ Window initially positioned: ({}, {})", x, y);
            return;
        }
        if let Ok(monitors) = window.available_monitors() {
            if let Some(monitor) = monitors.first() {
                let scale_factor = monitor.scale_factor();
                let physical_size = monitor.size();
                let logical_width = physical_size.width as f64 / scale_factor;
                let window_width = 410.0;
                let x = logical_width - window_width;
                let y = 0.0;
                let _ = window.set_position(LogicalPosition::new(x, y));
            }
        }
    }
}
#[allow(dead_code)]
pub fn stop_mouse_edge_monitor() {
    debug!("🛑 Mouse detection stopped");
}
pub fn update_mouse_edge_enabled(enabled: bool) {
    MOUSE_EDGE_ENABLED.store(enabled, std::sync::atomic::Ordering::Relaxed);
    debug!("🖱 Mouse edge detection enabled: {}", enabled);
}
#[cfg(target_os = "macos")]
fn setup_mouse_event_monitoring<R: Runtime>(app: AppHandle<R>) {
    use std::thread;
    use std::time::Duration;
    thread::spawn(move || loop {
        if !MOUSE_EDGE_ENABLED.load(std::sync::atomic::Ordering::Relaxed) {
            thread::sleep(Duration::from_millis(500));
            continue;
        }
        if let Some(screen) = get_active_screen_info() {
            if let Some((mouse_x, _)) = get_mouse_location() {
                if let Some(window) = app.get_webview_window("main") {
                    let window_width = window
                        .inner_size()
                        .ok()
                        .map(|s| {
                            let scale = window
                                .current_monitor()
                                .ok()
                                .flatten()
                                .map(|m| m.scale_factor())
                                .unwrap_or(2.0);
                            s.width as f64 / scale
                        })
                        .unwrap_or(410.0);
                    let right_edge = screen.x + screen.width;
                    let show_threshold = 2.0;
                    let hide_threshold = window_width;
                    let at_right_edge = mouse_x >= right_edge - show_threshold;
                    let outside_window = mouse_x < right_edge - hide_threshold;
                    let mut visible = IS_WINDOW_VISIBLE.lock().unwrap();
                    let mut auto_hide = IS_AUTO_HIDE_ENABLED.lock().unwrap();
                    if at_right_edge && !*visible {
                        if !window.is_visible().unwrap_or(false) {
                            let x = right_edge - window_width;
                            let y = screen.y;
                            let _ = window.set_position(LogicalPosition::new(x, y));
                            *visible = true;
                            *auto_hide = true;
                            let _ = window.emit("window-visible", true);
                            let _ = window.show();
                            let _ = window.set_focus();
                            debug!(
                                "✅ Window shown from mouse edge (Auto-hide enabled) at ({}, {})",
                                x, y
                            );
                        }
                    } else if outside_window && *visible && *auto_hide {
                        if window.is_visible().unwrap_or(false) {
                            *visible = false;
                            *auto_hide = false;
                            let _ = window.emit("window-visible", false);
                            thread::sleep(Duration::from_millis(150));
                            let _ = window.hide();
                            debug!("✅ Window hidden (left mouse edge)");
                        }
                    }
                }
            }
        }
        thread::sleep(Duration::from_millis(100));
    });
}
#[cfg(target_os = "macos")]
struct ScreenInfo {
    x: f64,
    y: f64,
    width: f64,
}
#[cfg(target_os = "macos")]
fn get_active_screen_info() -> Option<ScreenInfo> {
    unsafe {
        let event_class = class!(NSEvent);
        let mouse_loc: cocoa::foundation::NSPoint = msg_send![event_class, mouseLocation];
        let screen_class = class!(NSScreen);
        let screens: cocoa::base::id = msg_send![screen_class, screens];
        let count: usize = msg_send![screens, count];
        if count == 0 {
            return None;
        }
        let primary_screen: cocoa::base::id = msg_send![screens, objectAtIndex: 0];
        let primary_frame: cocoa::foundation::NSRect = msg_send![primary_screen, frame];
        let primary_height = primary_frame.size.height;
        for i in 0..count {
            let screen: cocoa::base::id = msg_send![screens, objectAtIndex: i];
            let frame: cocoa::foundation::NSRect = msg_send![screen, frame];
            if mouse_loc.x >= frame.origin.x
                && mouse_loc.x <= (frame.origin.x + frame.size.width)
                && mouse_loc.y >= frame.origin.y
                && mouse_loc.y <= (frame.origin.y + frame.size.height)
            {
                return Some(ScreenInfo {
                    x: frame.origin.x,
                    y: primary_height - (frame.origin.y + frame.size.height),
                    width: frame.size.width,
                });
            }
        }
    }
    None
}
#[cfg(target_os = "macos")]
fn get_mouse_location() -> Option<(f64, f64)> {
    unsafe {
        let event_class = class!(NSEvent);
        let pos: cocoa::foundation::NSPoint = msg_send![event_class, mouseLocation];
        Some((pos.x, pos.y))
    }
}
#[cfg(target_os = "windows")]
fn get_mouse_location() -> Option<(f64, f64)> {
    None
}
#[cfg(target_os = "windows")]
fn get_screen_width() -> Option<f64> {
    None
}

const RESIZE_WINDOW_WIDTH: f64 = 380.0;
const RESIZE_MIN_HEIGHT: f64 = 300.0;
const RESIZE_MAX_HEIGHT: f64 = 1400.0;

pub fn start_height_resize<R: Runtime>(window: &tauri::WebviewWindow<R>) {
    #[cfg(target_os = "macos")]
    {
        let mouse_y = get_mouse_location().map(|(_, y)| y).unwrap_or(0.0);
        let logical_height = window
            .inner_size()
            .ok()
            .and_then(|s| window.scale_factor().ok().map(|sf| s.height as f64 / sf))
            .unwrap_or(800.0);

        *RESIZE_START_MOUSE_Y.lock().unwrap() = mouse_y;
        *RESIZE_START_HEIGHT.lock().unwrap() = logical_height;
        IS_HEIGHT_RESIZING.store(true, std::sync::atomic::Ordering::Relaxed);

        let window_clone = window.clone();
        std::thread::spawn(move || {
            loop {
                if !IS_HEIGHT_RESIZING.load(std::sync::atomic::Ordering::Relaxed) {
                    break;
                }
                if let Some((_, current_y)) = get_mouse_location() {
                    let start_y = *RESIZE_START_MOUSE_Y.lock().unwrap();
                    let start_height = *RESIZE_START_HEIGHT.lock().unwrap();
                    // macOS Y increases upward, so moving down = Y decreases = height increases
                    let delta = start_y - current_y;
                    let new_height = (start_height + delta)
                        .max(RESIZE_MIN_HEIGHT)
                        .min(RESIZE_MAX_HEIGHT);
                    let _ = window_clone
                        .set_size(tauri::LogicalSize::new(RESIZE_WINDOW_WIDTH, new_height));
                }
                std::thread::sleep(std::time::Duration::from_millis(8));
            }
        });
    }
}

pub fn stop_height_resize<R: Runtime>(window: &tauri::WebviewWindow<R>) -> f64 {
    IS_HEIGHT_RESIZING.store(false, std::sync::atomic::Ordering::Relaxed);
    std::thread::sleep(std::time::Duration::from_millis(20));
    window
        .inner_size()
        .ok()
        .and_then(|s| window.scale_factor().ok().map(|sf| (s.height as f64 / sf).round()))
        .unwrap_or(0.0)
}
