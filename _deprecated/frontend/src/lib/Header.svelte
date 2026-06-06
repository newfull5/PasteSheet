<script>
  import { createEventDispatcher, onMount } from "svelte";
  import Input from "./ui/Input.svelte";
  export let title = "PasteSheet";
  export let showBack = false;
  export let searchQuery = "";
  export let placeholder = "Search Anything...";
  const dispatch = createEventDispatcher();
  let searchInput;
  export function focusSearch() {
    if (searchInput) searchInput.focus();
  }
  function handleBack() {
    dispatch("back");
  }
</script>
<header class="app-header">
  <div class="header-row">
    <div class="header-left">
      {#if showBack}
        <button class="btn-back" on:click={handleBack}>◀</button>
      {/if}
      <div class="header-title-container">
        <h1
          class={showBack ? "view-folder" : ""}
          style="opacity: {searchQuery ? 0 : 1}"
        >
          {title}
        </h1>
        <Input
          bind:this={searchInput}
          className="header-search {searchQuery ? 'active' : ''}"
          {placeholder}
          bind:value={searchQuery}
        />
      </div>
    </div>
    <div class="header-right">
      <button class="btn-settings" on:click={() => dispatch('settings')} title="Settings">
        ⚙
      </button>
    </div>
  </div>
</header>
<style>
  .app-header {
    position: relative;
    display: flex;
    align-items: center;
    margin-bottom: 20px;
    min-height: 40px;
    flex-shrink: 0;
  }
  .header-row {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .header-left {
    display: flex;
    align-items: center;
    flex: 1;
    overflow: hidden;
  }
  .header-title-container {
    position: relative;
    flex: 1;
    display: flex;
    align-items: center;
  }
  h1 {
    color: var(--color-accent);
    font-size: 22px;
    font-weight: 500;
    letter-spacing: 0.03em;
    margin: 0;
    padding-left: 8px;
    pointer-events: none;
    transition: opacity 0.2s ease;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  h1.view-folder {
    font-size: 18px;
    opacity: 0.9;
  }
  h1::after {
    content: "|";
    color: var(--color-accent);
    animation: blink 1s step-end infinite;
    margin-left: 2px;
  }
  @keyframes blink {
    50% {
      opacity: 0;
    }
  }
  :global(.header-search) {
    position: absolute !important;
    top: 0 !important;
    left: 0 !important;
    width: 100% !important;
    background: transparent !important;
    border: none !important;
    color: var(--color-accent) !important;
    font-size: 22px !important;
    font-weight: 500 !important;
    letter-spacing: 0.03em !important;
    outline: none !important;
    padding: 0 0 0 8px !important;
    margin: 0 !important;
    opacity: 0 !important;
    transition: opacity 0.2s ease !important;
  }
  :global(.header-search.active),
  :global(.header-search:focus) {
    opacity: 1 !important;
  }
  .view-folder + :global(.header-search) {
    font-size: 18px !important;
  }
  .btn-back {
    background: transparent;
    border: none;
    font-size: 16px;
    color: var(--color-accent);
    padding: 4px 8px;
    margin-right: 4px;
    cursor: pointer;
    border-radius: 6px;
    transition: all 0.2s;
  }
  .btn-back:hover {
    background: rgba(255, 255, 255, 0.1);
  }
  .header-right {
    display: flex;
    align-items: center;
    margin-left: 12px;
  }
  .btn-settings {
    background: transparent;
    border: none;
    font-size: 20px;
    color: var(--color-accent);
    opacity: 0.7;
    padding: 6px;
    cursor: pointer;
    border-radius: 8px;
    transition: all 0.2s;
    display: flex;
    align-items: center;
    justify-content: center;
    line-height: 1;
  }
  .btn-settings:hover {
    background: rgba(255, 255, 255, 0.1);
    opacity: 1;
    transform: rotate(30deg);
  }
</style>
