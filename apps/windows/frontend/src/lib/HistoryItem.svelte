<script>
  import { createEventDispatcher } from "svelte";
  import Button from "./ui/Button.svelte";
  import Input from "./ui/Input.svelte";
  export let item;
  export let isSelected = false;
  export let isEditing = false;
  export let editContent = "";
  export let editMemo = "";
  export let showFolderLabel = false;
  const dispatch = createEventDispatcher();
  function handleBack() {
    dispatch("back");
  }
  let pasteBtn;
  let editBtn;
  let deleteBtn;
  export let activeButtonIndex = -1; 
  export function focusButton(index) {
    if (index === 0 && pasteBtn) pasteBtn.focus();
    if (index === 1 && editBtn) editBtn.focus();
    if (index === 2 && deleteBtn) deleteBtn.focus();
  }
  function handleSelect() {
    dispatch("select");
  }
  function handlePaste() {
    dispatch("paste", item);
  }
  function handleEdit() {
    dispatch("edit", item);
  }
  function handleDelete() {
    dispatch("delete", item.id);
  }
  function handleSave() {
    dispatch("save", item);
  }
  function handleCancel() {
    dispatch("cancel");
  }
</script>
<div
  role="button"
  tabindex="0"
  class="history-item {isSelected ? 'selected' : ''}"
  on:click={handleSelect}
  on:keydown={(e) => {
    if (e.key === "Enter" && !isSelected) {
      handleSelect();
    }
  }}
>
  <div class="item-body">
    {#if isEditing}
      <div class="edit-mode">
        <Input
          className="memo-area"
          bind:value={editMemo}
          placeholder="Memo"
          autofocus={true}
        />
        <textarea class="edit-area" bind:value={editContent}></textarea>
        <div class="inline-actions">
          <Button
            size="sm"
            variant="primary"
            on:click={(e) => {
              e.stopPropagation();
              handleSave();
            }}>Save</Button
          >
          <Button
            size="sm"
            variant="secondary"
            on:click={(e) => {
              e.stopPropagation();
              handleCancel();
            }}>Cancel</Button
          >
        </div>
      </div>
    {:else}
      <div class="item-header-row">
        {#if item.memo}
          <div class="item-memo">{item.memo}</div>
        {/if}
        {#if showFolderLabel && item.directory}
          <div class="folder-label">{item.directory}</div>
        {/if}
      </div>
      <div class="item-content">{item.content}</div>
      {#if isSelected}
        <div class="item-meta">
          <span>{item.created_at}</span>
        </div>
        <div class="item-actions">
          <button
            bind:this={pasteBtn}
            class="btn-mini {activeButtonIndex === 0 ? 'primary' : ''}"
            on:click={(e) => {
              e.stopPropagation();
              handlePaste();
            }}
            on:keydown={(e) => e.key === "Enter" && e.stopPropagation()}
            >Paste</button
          >
          <button
            bind:this={editBtn}
            class="btn-mini {activeButtonIndex === 1 ? 'primary' : ''}"
            on:click={(e) => {
              e.stopPropagation();
              handleEdit();
            }}
            on:keydown={(e) => e.key === "Enter" && e.stopPropagation()}
            >Edit</button
          >
          <button
            bind:this={deleteBtn}
            class="btn-mini danger {activeButtonIndex === 2 ? 'primary' : ''}"
            on:click={(e) => {
              e.stopPropagation();
              handleDelete();
            }}
            on:keydown={(e) => e.key === "Enter" && e.stopPropagation()}
            >Delete</button
          >
        </div>
      {/if}
    {/if}
  </div>
</div>
<style>
  .history-item {
    display: flex;
    align-items: center;
    background: transparent;
    border-radius: 6px;
    padding: 12px 14px;
    cursor: pointer;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    position: relative;
    min-height: 44px;
    overflow: hidden;
  }
  .history-item.selected {
    background-color: rgba(220, 220, 87, 0.08);
    align-items: stretch;
    max-height: 800px;
    min-height: fit-content;
    overflow: visible;
    outline: none;
  }
  .history-item::before {
    content: "";
    display: block;
    width: 4px;
    height: 16px;
    background-color: var(--color-accent);
    margin-right: 16px;
    border-radius: 2px;
    opacity: 0.3;
    transition: all 0.2s;
    flex-shrink: 0;
  }
  .history-item.selected::before {
    height: auto;
    align-self: stretch;
    opacity: 1;
    box-shadow: 0 0 8px var(--color-accent);
  }
  .item-body {
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: center;
    overflow: hidden;
    width: 100%;
  }
  .item-header-row {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 4px;
    width: 100%;
    position: relative; 
  }
  .item-memo {
    flex: 1; 
    font-size: 13px;
    font-weight: 500;
    color: #e2e2b6;
    letter-spacing: 0.03em;
    line-height: 1.4;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 70%;
  }
  .folder-label {
    margin-left: auto; 
    font-size: 10px;
    color: var(--color-text-sub);
    background: rgba(255, 255, 255, 0.08);
    padding: 1px 6px;
    border-radius: 4px;
    white-space: nowrap;
    opacity: 0.6;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .item-content {
    flex: 1;
    font-size: 14px;
    color: rgba(255, 255, 255, 0.7);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    width: 100%;
  }
  .history-item.selected .item-content {
    color: var(--color-text-main);
    white-space: pre-wrap;
    display: -webkit-box;
    -webkit-line-clamp: 15;
    -webkit-box-orient: vertical;
    overflow: hidden;
    margin-top: 4px;
    margin-bottom: 16px;
    line-height: 1.6;
    flex: none;
    height: auto;
    text-overflow: clip;
    user-select: none;
  }
  .item-meta {
    display: none;
    color: var(--color-text-sub);
    font-size: 11px;
    font-family: monospace;
    opacity: 0.6;
  }
  .history-item.selected .item-meta {
    display: flex;
    border-top: 1px solid rgba(255, 255, 255, 0.05);
    padding-top: 8px;
    padding-bottom: 8px;
    width: 100%;
    justify-content: space-between;
    align-items: center;
  }
  .item-actions {
    display: none;
    gap: 8px;
    width: 100%;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    padding-top: 12px;
    padding-bottom: 4px;
    flex-shrink: 0;
  }
  .history-item.selected .item-actions {
    display: flex;
  }
  .btn-mini {
    padding: 4px 10px;
    font-size: 11px;
    border-radius: 4px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--color-text-sub);
    cursor: pointer;
    transition: all 0.2s;
    outline: none; 
  }
  .btn-mini:hover {
    background: rgba(255, 255, 255, 0.1);
    color: var(--color-text-main);
  }
  .btn-mini:focus {
    outline: none; 
  }
  .btn-mini.primary {
    background: var(--color-accent);
    color: black;
    border: 1px solid transparent; 
  }
  .btn-mini.danger:hover,
  .btn-mini.danger.primary {
    background: var(--color-accent-danger) !important;
    color: white !important;
    border-color: var(--color-accent-danger) !important;
  }
  .edit-mode {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  :global(.memo-area) {
    width: 100% !important;
    background: rgba(220, 220, 87, 0.05) !important;
    border: 1px solid rgba(220, 220, 87, 0.3) !important;
    color: var(--color-accent) !important;
    border-radius: 4px !important;
    padding: 8px 10px !important;
    font-size: 13px !important;
    font-weight: 600 !important;
    outline: none !important;
    margin-bottom: 8px !important;
    transition: all 0.2s !important;
  }
  .edit-area {
    width: 100%;
    min-height: 120px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(220, 220, 87, 0.2);
    color: white;
    padding: 10px;
    border-radius: 6px;
    outline: none;
    resize: vertical;
    font-family: inherit;
    font-size: 14px;
    line-height: 1.5;
    margin-bottom: 8px;
    transition: all 0.2s;
  }
  .edit-area:focus {
    border-color: var(--color-accent);
    background: rgba(220, 220, 87, 0.08);
    box-shadow: 0 0 0 2px rgba(220, 220, 87, 0.1);
  }
  .inline-actions {
    display: flex;
    gap: 8px;
    margin-top: 4px;
  }
</style>
