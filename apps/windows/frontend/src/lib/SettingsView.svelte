<script>
  import { createEventDispatcher, onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import { getVersion } from "@tauri-apps/api/app";
  import Toggle from "./ui/Toggle.svelte";
  const dispatch = createEventDispatcher();
  let settings = {
    mouse_edge_enabled: null,
    auto_hide_enabled: null,
    auto_hide_timeout: 5,
    shortcut: "CommandOrControl+Shift+V",
  };
  let autoStart = null;
  let version = "";
  let isRecording = false;
  let recordingDisplay = "";

  function formatShortcutDisplay(shortcut) {
    return shortcut
      .replace(/CommandOrControl/g, "⌘")
      .replace(/Shift/g, "⇧")
      .replace(/Alt/g, "⌥")
      .replace(/Control/g, "⌃")
      .replace(/\+/g, " ");
  }

  function startRecording() {
    isRecording = true;
    recordingDisplay = "Press keys...";
  }

  function handleKeyDown(e) {
    if (!isRecording) return;
    e.preventDefault();
    e.stopPropagation();

    if (!e.metaKey && !e.ctrlKey && !e.altKey && !e.shiftKey) return;
    if (["Meta", "Control", "Alt", "Shift"].includes(e.key)) return;

    const parts = [];
    if (e.metaKey || e.ctrlKey) parts.push("CommandOrControl");
    if (e.shiftKey) parts.push("Shift");
    if (e.altKey) parts.push("Alt");

    const key = e.code.replace(/^Key/, "").replace(/^Digit/, "");
    parts.push(key);

    const shortcutStr = parts.join("+");
    isRecording = false;
    recordingDisplay = "";
    saveShortcut(shortcutStr);
  }

  async function saveShortcut(shortcutStr) {
    try {
      await invoke("update_shortcut", { shortcut: shortcutStr });
      settings.shortcut = shortcutStr;
    } catch (err) {
      console.error("Failed to update shortcut:", err);
    }
  }

  function cancelRecording() {
    isRecording = false;
    recordingDisplay = "";
  }
  onMount(async () => {
    try {
      const mouseEdge = await invoke("get_setting", { key: "mouse_edge_enabled" });
      settings.mouse_edge_enabled = mouseEdge === null ? false : mouseEdge === "true";
      const autoHide = await invoke("get_setting", { key: "auto_hide_enabled" });
      settings.auto_hide_enabled = autoHide === null ? false : autoHide === "true";
      const autoHideTimeout = await invoke("get_setting", { key: "auto_hide_timeout" });
      settings.auto_hide_timeout = autoHideTimeout ? parseInt(autoHideTimeout) : 5;
      const shortcut = await invoke("get_setting", { key: "shortcut" });
      settings.shortcut = shortcut || "CommandOrControl+Shift+V";
    } catch (err) {
      console.error("Failed to load settings:", err);
      settings.mouse_edge_enabled = false;
      settings.auto_hide_enabled = false;
    }
    try {
      autoStart = await invoke("get_autostart");
    } catch (err) {
      console.error("Failed to load autostart state:", err);
      autoStart = false;
    }
    try {
      version = await getVersion();
    } catch (_) {}
  });
  async function updateAutostart(enabled) {
    try {
      await invoke("set_autostart", { enabled });
      autoStart = enabled;
    } catch (err) {
      console.error("Failed to update autostart:", err);
    }
  }
  async function updateSetting(key, value) {
    try {
      await invoke("update_setting", { key, value: String(value) });
      settings[key] = value;
      dispatch("settingschange", { key, value });
    } catch (err) {
      console.error(`Failed to update setting ${key}:`, err);
    }
  }
  function handleBack() {
    dispatch("back");
  }
</script>
<!-- svelte-ignore a11y-no-static-element-interactions -->
<svelte:window on:keydown={handleKeyDown} on:click={() => { if (isRecording) cancelRecording(); }} />
<div class="settings-view">
  <div class="settings-group">
    <h3 class="group-title">Shortcut</h3>
    <div class="shortcut-row">
      <div class="shortcut-info">
        <span class="shortcut-label">Toggle Window</span>
      </div>
      {#if isRecording}
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="shortcut-key recording" on:click|stopPropagation={() => cancelRecording()}>
          {recordingDisplay}
        </div>
      {:else}
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="shortcut-key" on:click|stopPropagation={() => startRecording()}>
          {formatShortcutDisplay(settings.shortcut)}
        </div>
      {/if}
    </div>
  </div>
  <div class="settings-group">
    <h3 class="group-title">General</h3>
    {#if autoStart !== null}
      <Toggle
        label="Launch at Login"
        description="Automatically start PasteSheets when you log in."
        checked={autoStart}
        on:change={(e) => updateAutostart(e.detail)}
      />
    {/if}
    {#if settings.mouse_edge_enabled !== null}
      <Toggle
        label="Mouse Edge Detection"
        description="Slide into the screen when the mouse hits the right edge."
        checked={settings.mouse_edge_enabled}
        on:change={(e) => updateSetting("mouse_edge_enabled", e.detail)}
      />
    {/if}
    {#if settings.auto_hide_enabled !== null}
      <Toggle
        label="Auto-hide"
        description="Automatically hide the window after a period of inactivity."
        checked={settings.auto_hide_enabled}
        on:change={(e) => updateSetting("auto_hide_enabled", e.detail)}
      />
      {#if settings.auto_hide_enabled}
        <div class="timeout-row">
          <span class="timeout-label">Hide after</span>
          <div class="timeout-segments">
            {#each [3, 5, 10, 30, 60] as sec}
              <!-- svelte-ignore a11y-no-static-element-interactions -->
              <div
                class="segment {settings.auto_hide_timeout === sec ? 'active' : ''}"
                on:click={() => updateSetting("auto_hide_timeout", sec)}
              >{sec}s</div>
            {/each}
          </div>
        </div>
      {/if}
    {/if}
  </div>
  <div class="settings-group">
    <h3 class="group-title">Information</h3>
    <div class="info-item">
      <span class="info-label">Version</span>
      <span class="info-value">{version}</span>
    </div>
    <div class="info-item">
      <span class="info-label">Developer</span>
      <span class="info-value">newfull5</span>
    </div>
  </div>
</div>
<style>
  .settings-view {
    display: flex;
    flex-direction: column;
    gap: 24px;
    padding: 4px;
    height: 100%;
    overflow-y: auto;
  }
  .settings-group {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .group-title {
    color: var(--color-text-sub);
    font-size: 13px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 4px;
    padding-left: 4px;
  }
  .info-item {
    display: flex;
    justify-content: space-between;
    padding: 12px;
    background: rgba(255, 255, 255, 0.03);
    border-radius: 12px;
  }
  .info-label {
    color: var(--color-text-sub);
    font-size: 14px;
  }
  .info-value {
    color: var(--color-text-main);
    font-size: 14px;
    font-weight: 500;
  }
  .timeout-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 12px;
    background: rgba(255, 255, 255, 0.03);
    border-radius: 12px;
  }
  .timeout-label {
    color: var(--color-text-sub);
    font-size: 14px;
  }
  .timeout-segments {
    display: flex;
    gap: 4px;
    background: rgba(255, 255, 255, 0.05);
    border-radius: 10px;
    padding: 3px;
  }
  .segment {
    padding: 4px 10px;
    border-radius: 7px;
    font-size: 13px;
    font-weight: 500;
    color: var(--color-text-sub);
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
    user-select: none;
  }
  .segment:hover {
    color: var(--color-text-main);
  }
  .segment.active {
    background: rgba(255, 255, 255, 0.15);
    color: var(--color-text-main);
  }
  .shortcut-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px;
    background: rgba(255, 255, 255, 0.03);
    border-radius: 12px;
  }
  .shortcut-label {
    color: var(--color-text-main);
    font-size: 14px;
    font-weight: 500;
  }
  .shortcut-key {
    padding: 6px 14px;
    background: rgba(255, 255, 255, 0.08);
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
    color: var(--color-text-main);
    cursor: pointer;
    transition: background 0.15s;
    letter-spacing: 0.05em;
    user-select: none;
  }
  .shortcut-key:hover {
    background: rgba(255, 255, 255, 0.14);
  }
  .shortcut-key.recording {
    background: rgba(99, 102, 241, 0.25);
    color: rgba(165, 180, 252, 1);
    animation: pulse 1.2s ease-in-out infinite;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.6; }
  }
</style>
