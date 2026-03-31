<script>
  import { createEventDispatcher, onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import Toggle from "./ui/Toggle.svelte";
  const dispatch = createEventDispatcher();
  let settings = {
    mouse_edge_enabled: null,
  };
  onMount(async () => {
    try {
      const val = await invoke("get_setting", { key: "mouse_edge_enabled" });
      settings.mouse_edge_enabled = val === null ? false : val === "true";
    } catch (err) {
      console.error("Failed to load settings:", err);
      settings.mouse_edge_enabled = false;
    }
  });
  async function updateSetting(key, value) {
    try {
      await invoke("update_setting", { key, value: String(value) });
      settings[key] = value;
    } catch (err) {
      console.error(`Failed to update setting ${key}:`, err);
    }
  }
  function handleBack() {
    dispatch("back");
  }
</script>
<div class="settings-view">
  <div class="settings-group">
    <h3 class="group-title">General</h3>
    {#if settings.mouse_edge_enabled !== null}
      <Toggle
        label="Mouse Edge Detection"
        description="Slide into the screen when the mouse hits the right edge."
        checked={settings.mouse_edge_enabled}
        on:change={(e) => updateSetting("mouse_edge_enabled", e.detail)}
      />
    {/if}
  </div>
  <div class="settings-group">
    <h3 class="group-title">Information</h3>
    <div class="info-item">
      <span class="info-label">Version</span>
      <span class="info-value">0.1.0</span>
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
</style>
