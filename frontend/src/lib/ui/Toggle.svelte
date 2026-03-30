<script>
  import { createEventDispatcher, onMount } from "svelte";
  export let checked = false;
  export let label = "";
  export let description = "";
  const dispatch = createEventDispatcher();
  let mounted = false;
  onMount(() => { mounted = true; });
  function toggle() {
    checked = !checked;
    dispatch("change", checked);
  }
</script>
<div class="toggle-container" on:click={toggle}>
  <div class="toggle-info">
    <span class="toggle-label">{label}</span>
    {#if description}
      <span class="toggle-description">{description}</span>
    {/if}
  </div>
  <div class="toggle-switch {checked ? 'checked' : ''} {mounted ? 'animated' : ''}">
    <div class="toggle-handle"></div>
  </div>
</div>
<style>
  .toggle-container {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px border transparent;
    border-radius: 12px;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .toggle-container:hover {
    background: rgba(255, 255, 255, 0.08);
  }
  .toggle-info {
    display: flex;
    flex-direction: column;
    gap: 4px;
    flex: 1;
  }
  .toggle-label {
    color: var(--color-text-main);
    font-size: 15px;
    font-weight: 500;
  }
  .toggle-description {
    color: var(--color-text-sub);
    font-size: 12px;
  }
  .toggle-switch {
    width: 44px;
    height: 24px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 20px;
    position: relative;
  }
  .toggle-switch.animated {
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .toggle-switch.checked {
    background: var(--color-accent);
  }
  .toggle-handle {
    width: 18px;
    height: 18px;
    background: white;
    border-radius: 50%;
    position: absolute;
    top: 3px;
    left: 3px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
  }
  .toggle-switch.animated .toggle-handle {
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .toggle-switch.checked .toggle-handle {
    transform: translateX(20px);
  }
</style>
