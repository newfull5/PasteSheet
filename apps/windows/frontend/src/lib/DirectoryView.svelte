<script>
  import { createEventDispatcher } from "svelte";
  import { flip } from "svelte/animate";
  import { fly } from "svelte/transition";
  import Input from "./ui/Input.svelte";
  import ContextMenu from "./ui/ContextMenu.svelte";
  export let directories = [];
  export let selectedIndex = 0;
  let isCreating = false;
  let newFolderName = "";
  let inlineInput;
  const dispatch = createEventDispatcher();
  let contextMenu = { show: false, x: 0, y: 0, targetDir: null };
  function scrollSelected(node, isSelected) {
    if (isSelected) {
      node.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }
  function handleSelect(index) {
    selectedIndex = index;
    dispatch("select", selectedIndex);
  }
  function handleOpen(dirName) {
    dispatch("open", dirName);
  }
  function handleRename(dirName) {
    dispatch("rename", dirName);
  }
  function handleDelete(dirName) {
    dispatch("delete", dirName);
  }
  export function handleCreate() {
    isCreating = true;
  }
  function handleSaveCreate() {
    const name = newFolderName.trim();
    if (name) {
      dispatch("create", name);
    }
    cancelCreate();
  }
  function cancelCreate() {
    isCreating = false;
    newFolderName = "";
  }
  function autofocus(node) {
    node.focus();
  }
  function handleContextMenu(e, dir) {
    e.preventDefault();
    contextMenu = {
      show: true,
      x: e.clientX,
      y: e.clientY,
      targetDir: dir,
    };
  }
  function handleContextSelect(e) {
    const action = e.detail;
    if (contextMenu.targetDir) {
      if (action === "rename") handleRename(contextMenu.targetDir.name);
      if (action === "delete") handleDelete(contextMenu.targetDir.name);
    }
  }
</script>
<div id="view-directories" class="view-page">
  <div class="content-list">
    {#each directories as dir, i (dir.name)}
      <div
        animate:flip={{ duration: 300 }}
        transition:fly={{ y: 20, duration: 200 }}
        role="button"
        tabindex="0"
        class="dir-item {selectedIndex === i ? 'selected' : ''}"
        use:scrollSelected={selectedIndex === i}
        on:click={() => handleOpen(dir.name)}
        on:contextmenu={(e) => handleContextMenu(e, dir)}
      >
        <div class="dir-body">
          <span class="dir-name">{dir.name}</span>
          <span class="dir-count">{dir.count}</span>
        </div>
      </div>
    {/each}
    <div
      role="button"
      tabindex="0"
      class="btn-new {selectedIndex === directories.length
        ? 'selected'
        : ''} {isCreating ? 'active' : ''}"
      use:scrollSelected={selectedIndex === directories.length}
      on:click={handleCreate}
      on:keydown={(e) => (e.key === "Enter" || e.key === " ") && handleCreate()}
    >
      {#if isCreating}
        <input
          bind:this={inlineInput}
          type="text"
          class="inline-input"
          placeholder="Folder Name..."
          bind:value={newFolderName}
          on:blur={cancelCreate}
          on:keydown={(e) => {
            e.stopPropagation();
            if (e.key === "Enter") handleSaveCreate();
            if (e.key === "Escape") cancelCreate();
          }}
          use:autofocus
        />
      {:else}
        <span>New Folder</span>
      {/if}
    </div>
    {#if contextMenu.show}
      <ContextMenu
        x={contextMenu.x}
        y={contextMenu.y}
        options={[
          { label: "Rename", action: "rename" },
          { label: "Delete", action: "delete", danger: true },
        ]}
        on:select={handleContextSelect}
        on:close={() => (contextMenu.show = false)}
      />
    {/if}
  </div>
</div>
<style>
  .view-page {
    display: flex;
    flex-direction: column;
    width: 100%;
    height: 100%;
  }
  .content-list {
    display: flex;
    flex-direction: column;
    gap: 4px;
    overflow-y: auto;
    padding-right: 2px;
    flex: 1;
    scrollbar-width: thin;
    scrollbar-color: rgba(220, 220, 87, 0.2) transparent;
  }
  .content-list::-webkit-scrollbar {
    width: 4px;
  }
  .content-list::-webkit-scrollbar-track {
    background: transparent;
  }
  .content-list::-webkit-scrollbar-thumb {
    background: rgba(220, 220, 87, 0.2);
    border-radius: 2px;
  }
  .content-list::-webkit-scrollbar-thumb:hover {
    background: rgba(220, 220, 87, 0.4);
  }
  .dir-item {
    display: flex;
    align-items: center;
    background: transparent;
    border-radius: 6px;
    padding: 12px 12px;
    cursor: pointer;
    transition: background 0.1s;
    position: relative;
    color: var(--color-text-main);
    border-bottom: 1px solid rgba(255, 255, 255, 0.03);
    outline: none;
  }
  .dir-item:hover,
  .dir-item.selected {
    background-color: rgba(255, 255, 255, 0.05);
    outline: none;
  }
  .dir-item.selected {
    background-color: rgba(220, 220, 87, 0.1);
  }
  .dir-item::before {
    content: "";
    display: block;
    width: 4px;
    height: 18px;
    background-color: var(--color-text-sub);
    margin-right: 12px;
    border-radius: 2px;
    opacity: 0.4;
    transition: all 0.2s;
    flex-shrink: 0;
  }
  .dir-item:hover::before,
  .dir-item.selected::before {
    background-color: var(--color-accent);
    opacity: 1;
    box-shadow: 0 0 8px var(--color-accent);
  }
  .dir-body {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: space-between;
    overflow: hidden;
  }
  .dir-name {
    flex: 1;
    font-size: 15px;
    font-weight: 400;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .dir-count {
    font-size: 12px;
    color: var(--color-text-sub);
    background: rgba(255, 255, 255, 0.08);
    padding: 2px 8px;
    border-radius: 10px;
    min-width: 24px;
    text-align: center;
  }
</style>
