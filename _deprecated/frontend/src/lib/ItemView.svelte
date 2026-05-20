<script>
  import { createEventDispatcher } from "svelte";
  import { flip } from "svelte/animate";
  import { fly } from "svelte/transition";
  import HistoryItem from "./HistoryItem.svelte";
  import Button from "./ui/Button.svelte";
  import Input from "./ui/Input.svelte";
  export let historyItems = [];
  export let selectedIndex = 0;
  export let editingId = null;
  export let editContent = "";
  export let editMemo = "";
  const dispatch = createEventDispatcher();
  let itemRefs = [];
  let buttonFocusIndex = 0;
  $: filteredItems = historyItems;
  let isCreating = false;
  let newItemMemo = "";
  let newItemContent = "";
  let lastSelectedIndex = -1;
  $: if (selectedIndex !== undefined && selectedIndex !== lastSelectedIndex) {
    buttonFocusIndex = 0;
    lastSelectedIndex = selectedIndex;
  }
  function handleBack() {
    dispatch("back");
  }
  function handleSelect(index) {
    if (selectedIndex === index) return; 
    selectedIndex = index;
    dispatch("select", index);
  }
  function handlePaste(event) {
    dispatch("paste", event.detail);
  }
  function handleEdit(event) {
    dispatch("edit", event.detail);
  }
  function handleDelete(event) {
    dispatch("delete", event.detail);
  }
  function handleSave() {
    dispatch("save");
  }
  function handleCancel() {
    dispatch("cancel");
  }
  function handleCreate() {
    isCreating = true;
  }
  function handleSaveCreate() {
    const content = newItemContent.trim();
    if (content) {
      dispatch("create", { content, memo: newItemMemo.trim() || null });
    }
    cancelCreate();
  }
  function cancelCreate() {
    isCreating = false;
    newItemMemo = "";
    newItemContent = "";
  }
  function autofocus(node) {
    node.focus();
  }
  function scrollSelected(node, selected) {
    if (selected) {
      node.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
    return {
      update(newSelected) {
        if (newSelected) {
          node.scrollIntoView({ behavior: "smooth", block: "nearest" });
        }
      },
    };
  }
  export function executeSelectedAction() {
    if (selectedIndex === filteredItems.length) {
      handleCreate();
    } else if (filteredItems[selectedIndex]) {
      const item = filteredItems[selectedIndex];
      if (buttonFocusIndex === 0) {
        dispatch("paste", item);
      } else if (buttonFocusIndex === 1) {
        dispatch("edit", item);
      } else if (buttonFocusIndex === 2) {
        dispatch("delete", item.id);
      }
    }
  }
  export function handleArrowKey(key) {
    if (editingId !== null || isCreating) return false;
    if (key === "ArrowRight") {
      if (buttonFocusIndex < 2) {
        buttonFocusIndex++;
        if (itemRefs[selectedIndex]) {
          itemRefs[selectedIndex].focusButton(buttonFocusIndex);
        }
        return true;
      }
      return false; 
    } else if (key === "ArrowLeft") {
      if (buttonFocusIndex > 0) {
        buttonFocusIndex--;
        if (itemRefs[selectedIndex]) {
          itemRefs[selectedIndex].focusButton(buttonFocusIndex);
        }
        return true; 
      } else {
        return false; 
      }
    }
    return false;
  }
</script>
<div id="view-items" class="view-page">
  <div class="content-list">
    {#each filteredItems as item, i (item.id)}
      <div
        animate:flip={{ duration: 300 }}
        transition:fly={{ y: 20, duration: 200 }}
        use:scrollSelected={selectedIndex === i}
      >
        <HistoryItem
          bind:this={itemRefs[i]}
          {item}
          isSelected={selectedIndex === i}
          activeButtonIndex={selectedIndex === i ? buttonFocusIndex : -1}
          isEditing={editingId === item.id}
          bind:editContent
          bind:editMemo
          on:select={() => handleSelect(i)}
          on:paste={handlePaste}
          on:edit={handleEdit}
          on:delete={handleDelete}
          on:save={handleSave}
          on:cancel={handleCancel}
          on:view={() => dispatch("view", item)}
        />
      </div>
    {/each}
    <div
      role="button"
      tabindex="0"
      class="btn-new accent-text {selectedIndex === filteredItems.length
        ? 'selected'
        : ''} {isCreating ? 'active' : ''}"
      use:scrollSelected={selectedIndex === filteredItems.length}
      on:click={handleCreate}
      on:keydown={(e) => (e.key === "Enter" || e.key === " ") && handleCreate()}
    >
      {#if isCreating}
        <div class="item-body" style="width: 100%;">
          <input
            type="text"
            class="inline-memo"
            placeholder="Memo (Optional)..."
            bind:value={newItemMemo}
            use:autofocus
            on:keydown={(e) => {
              e.stopPropagation();
              if (e.key === "Enter") {
                e.preventDefault();
                const contentArea = e.target.nextElementSibling;
                if (contentArea) contentArea.focus();
              } else if (e.key === "Escape") {
                cancelCreate();
              }
            }}
          />
          <textarea
            class="inline-content"
            placeholder="Content (⌘+Enter to save)..."
            bind:value={newItemContent}
            on:keydown={(e) => {
              e.stopPropagation();
              if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
                e.preventDefault();
                handleSaveCreate();
              } else if (e.key === "Escape") {
                cancelCreate();
              }
            }}
          ></textarea>
          <div class="inline-actions">
            <Button
              variant="primary"
              size="sm"
              on:click={(e) => {
                e.stopPropagation();
                handleSaveCreate();
              }}>Save</Button
            >
            <Button
              variant="secondary"
              size="sm"
              on:click={(e) => {
                e.stopPropagation();
                cancelCreate();
              }}>Cancel</Button
            >
          </div>
        </div>
      {:else}
        <span>New Item</span>
      {/if}
    </div>
    {#if filteredItems.length === 0}
      <div class="empty-state">No items found in this folder</div>
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
  }
  .content-list::-webkit-scrollbar {
    width: 6px;
  }
  .content-list::-webkit-scrollbar-thumb {
    background: rgba(220, 220, 87, 0.2);
    border-radius: 10px;
  }
  .content-list::-webkit-scrollbar-thumb:hover {
    background: rgba(220, 220, 87, 0.4);
  }
  .empty-state {
    color: var(--color-text-sub);
    text-align: center;
    padding: 40px 0;
    font-size: 14px;
  }
</style>
