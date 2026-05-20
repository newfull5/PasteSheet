<script>
  import { createEventDispatcher } from "svelte";
  import HistoryItem from "./HistoryItem.svelte";
  import { flip } from "svelte/animate";
  import { fly } from "svelte/transition";
  export let filteredDirectories = [];
  export let filteredItems = [];
  export let selectedIndex = 0;
  let itemRefs = [];
  let buttonFocusIndex = 0;
  export let editingId = null;
  export let editContent = "";
  export let editMemo = "";
  const dispatch = createEventDispatcher();
  function scrollSelected(node, isSelected) {
    if (isSelected) {
      node.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }
  $: totalFolders = filteredDirectories.length;
  $: totalItems = filteredItems.length;
  $: totalCount = totalFolders + totalItems;
  export function executeSelectedAction() {
    if (selectedIndex < totalFolders) {
      dispatch("openFolder", filteredDirectories[selectedIndex].name);
    } else {
      const itemIdx = selectedIndex - totalFolders;
      const item = filteredItems[itemIdx];
      if (item) {
        if (buttonFocusIndex === 0) dispatch("paste", item);
        else if (buttonFocusIndex === 1) {
          dispatch("edit", item);
        } else if (buttonFocusIndex === 2) dispatch("delete", item.id);
      }
    }
  }
  export function handleArrowKey(key) {
    if (selectedIndex < totalFolders) return;
    const maxButtonIndex = 2;
    if (key === "ArrowRight") {
      if (buttonFocusIndex < maxButtonIndex) {
        buttonFocusIndex++;
        const itemIdx = selectedIndex - totalFolders;
        if (itemRefs[itemIdx]) itemRefs[itemIdx].focusButton(buttonFocusIndex);
      }
    } else if (key === "ArrowLeft") {
      if (buttonFocusIndex > 0) {
        buttonFocusIndex--;
        const itemIdx = selectedIndex - totalFolders;
        if (itemRefs[itemIdx]) itemRefs[itemIdx].focusButton(buttonFocusIndex);
      }
    }
  }
  let lastSelectedIndex = -1;
  $: if (selectedIndex !== lastSelectedIndex) {
    buttonFocusIndex = 0;
    lastSelectedIndex = selectedIndex;
  }
</script>
<div class="search-view">
  <div class="search-content">
    {#if totalFolders > 0}
      <div class="search-section">
        <h2 class="search-section-header">Folders</h2>
        <div class="search-list">
          {#each filteredDirectories as dir, i (dir.name)}
            <div
              role="button"
              tabindex="0"
              class="search-result-item dir-result {selectedIndex === i
                ? 'selected'
                : ''}"
              use:scrollSelected={selectedIndex === i}
              on:click={() => dispatch("openFolder", dir.name)}
            >
              <div class="dir-icon"></div>
              <span class="dir-name">{dir.name}</span>
              <span class="dir-count">{dir.count}</span>
            </div>
          {/each}
        </div>
      </div>
    {/if}
    {#if totalItems > 0}
      <div class="search-section">
        <h2 class="search-section-header">Items</h2>
        <div class="search-list">
          {#each filteredItems as item, i (item.id)}
            <div
              use:scrollSelected={selectedIndex === totalFolders + i}
              class="search-item-wrapper"
            >
              <HistoryItem
                bind:this={itemRefs[i]}
                {item}
                isSelected={selectedIndex === totalFolders + i}
                activeButtonIndex={selectedIndex === totalFolders + i
                  ? buttonFocusIndex
                  : -1}
                isEditing={editingId === item.id}
                bind:editContent
                bind:editMemo
                on:select={() => (selectedIndex = totalFolders + i)}
                on:paste={() => dispatch("paste", item)}
                on:edit={() => {
                  dispatch("edit", item);
                }}
                on:delete={() => dispatch("delete", item.id)}
                on:save={() => dispatch("save", item)}
                on:cancel={() => dispatch("cancel")}
                on:view={() => dispatch("view", item)}
                showFolderLabel={true}
              />
            </div>
          {/each}
        </div>
      </div>
    {/if}
    {#if totalCount === 0}
      <div class="empty-state">No matches found for your search.</div>
    {/if}
  </div>
</div>
<style>
  .search-view {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }
  .search-content {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 20px;
    padding-right: 4px;
  }
  .search-section {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .search-section-header {
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--color-text-sub);
    letter-spacing: 0.1em;
    padding-left: 8px;
    margin-bottom: 4px;
    opacity: 0.7;
  }
  .search-list {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .search-result-item {
    display: flex;
    align-items: center;
    padding: 10px 12px;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
    background: transparent;
  }
  .search-result-item:hover,
  .search-result-item.selected {
    background: rgba(255, 255, 255, 0.05);
  }
  .search-result-item.selected {
    background-color: rgba(220, 220, 87, 0.1);
  }
  .dir-icon {
    width: 4px;
    height: 16px;
    background: var(--color-text-sub);
    margin-right: 12px;
    border-radius: 2px;
    opacity: 0.4;
  }
  .search-result-item.selected .dir-icon {
    background: var(--color-accent);
    opacity: 1;
    box-shadow: 0 0 8px var(--color-accent);
  }
  .dir-name {
    flex: 1;
    font-size: 14px;
    color: var(--color-text-main);
  }
  .dir-count {
    font-size: 12px;
    color: var(--color-text-sub);
    background: rgba(255, 255, 255, 0.08);
    padding: 2px 8px;
    border-radius: 10px;
  }
  .empty-state {
    color: var(--color-text-sub);
    text-align: center;
    padding: 60px 0;
    font-size: 14px;
  }
  .search-item-wrapper {
    margin-bottom: 2px;
  }
</style>
