<script>
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import { listen } from "@tauri-apps/api/event";
  import { getCurrentWindow } from "@tauri-apps/api/window";
  import { LogicalSize } from "@tauri-apps/api/dpi";
  import { fly } from "svelte/transition";
  import DirectoryView from "./lib/DirectoryView.svelte";
  import ItemView from "./lib/ItemView.svelte";
  import SearchView from "./lib/SearchView.svelte";
  import Header from "./lib/Header.svelte";
  import Modal from "./lib/Modal.svelte";
  import DetailModal from "./lib/DetailModal.svelte";
  import SettingsView from "./lib/SettingsView.svelte";
  let isVisible = false;
  let currentView = "directories";
  // --- Auto-hide ---
  let autoHideEnabled = false;
  let autoHideTimeout = 5;
  let autoHideTimer = null;

  function resetAutoHideTimer() {
    if (!autoHideEnabled || !isVisible) return;
    clearTimeout(autoHideTimer);
    autoHideTimer = setTimeout(() => {
      invoke("toggle_main_window");
    }, autoHideTimeout * 1000);
  }

  function clearAutoHideTimer() {
    clearTimeout(autoHideTimer);
    autoHideTimer = null;
  }

  function handleSettingsChange(e) {
    const { key, value } = e.detail;
    if (key === "auto_hide_enabled") {
      autoHideEnabled = value;
      if (isVisible && autoHideEnabled) resetAutoHideTimer();
      else clearAutoHideTimer();
    } else if (key === "auto_hide_timeout") {
      autoHideTimeout = value;
      if (isVisible && autoHideEnabled) resetAutoHideTimer();
    }
  }
  // --- End auto-hide ---
  let directories = [];
  let historyItems = [];
  let currentDirId = "";
  let searchQuery = "";
  let selectedIndex = 0;
  let editingId = null;
  let editContent = "";
  let editMemo = "";
  let modalConfig = {
    show: false,
    title: "",
    message: "",
    confirmText: "Confirm",
    cancelText: "Cancel",
    isDanger: false,
    showInput: false,
    inputValue: "",
    onConfirm: (val) => {},
  };
  function openModal(config) {
    modalConfig = {
      show: true,
      title: "Confirm",
      message: "",
      confirmText: "Confirm",
      cancelText: "Cancel",
      isDanger: false,
      showInput: false,
      inputValue: "",
      onConfirm: (val) => {},
      ...config,
    };
  }
  function closeModal() {
    modalConfig.show = false;
  }
  function handleModalConfirm(event) {
    if (modalConfig.onConfirm) {
      modalConfig.onConfirm(event.detail);
    }
    closeModal();
  }
  let detailItem = null;
  function handleView(item) {
    if (item) {
      detailItem = item;
    }
  }
  function closeDetail() {
    detailItem = null;
  }
  let isLoading = false;
  $: filteredDirectories = directories.filter((d) =>
    d.name.toLowerCase().includes(searchQuery.toLowerCase()),
  );
  $: filteredItems = historyItems.filter(
    (item) =>
      item.directory === currentDirId &&
      ((item.content &&
        item.content.toLowerCase().includes(searchQuery.toLowerCase())) ||
        (item.memo &&
          item.memo.toLowerCase().includes(searchQuery.toLowerCase()))),
  );
  $: globalFilteredItems = historyItems.filter(
    (item) =>
      (item.content &&
        item.content.toLowerCase().includes(searchQuery.toLowerCase())) ||
      (item.memo &&
        item.memo.toLowerCase().includes(searchQuery.toLowerCase())),
  );
  $: {
    let listCount = 0;
    if (searchQuery) {
      listCount = filteredDirectories.length + globalFilteredItems.length;
    } else if (currentView === "directories") {
      listCount = filteredDirectories.length + 1; 
    } else {
      listCount = filteredItems.length + 1; 
    }
    if (selectedIndex >= listCount && listCount > 0) {
      selectedIndex = listCount - 1;
    } else if (listCount === 0) {
      selectedIndex = 0;
    }
  }
  $: if (
    currentView === "items" &&
    itemView &&
    !searchQuery &&
    selectedIndex !== undefined
  ) {
  }
  onMount(async () => {
    const savedHeight = localStorage.getItem("windowHeight");
    if (savedHeight) {
      const h = parseInt(savedHeight);
      if (h >= MIN_HEIGHT && h <= MAX_HEIGHT) {
        await getCurrentWindow().setSize(new LogicalSize(WINDOW_WIDTH, h));
      }
    }

    try {
      const enabled = await invoke("get_setting", { key: "auto_hide_enabled" });
      const timeout = await invoke("get_setting", { key: "auto_hide_timeout" });
      autoHideEnabled = enabled === "true";
      autoHideTimeout = timeout ? parseInt(timeout) : 5;
    } catch (_) {}

    await listen("window-visible", async (event) => {
      isVisible = event.payload;
      if (isVisible) {
        await loadDirectories();
        await loadHistory();
        resetAutoHideTimer();
      } else {
        clearAutoHideTimer();
      }
    });
    await listen("clipboard-updated", async () => {
      await loadDirectories();
      await loadHistory(); 
    });
    await loadDirectories();
    await loadHistory(); 
  });
  async function loadDirectories() {
    isLoading = true;
    try {
      directories = await invoke("get_directories");
    } catch (err) {
      console.error("Failed to load directories:", err);
    } finally {
      isLoading = false;
    }
  }
  async function showItemView(dirName) {
    currentDirId = dirName;
    currentView = "items";
    searchQuery = "";
    selectedIndex = 0;
    await loadHistory();
  }
  async function loadHistory() {
    isLoading = true;
    try {
      historyItems = await invoke("get_clipboard_history");
    } catch (err) {
      console.error("Failed to load history:", err);
    } finally {
      isLoading = false;
    }
  }
  async function showDirectoryView() {
    const lastActiveDir = currentDirId;
    currentView = "directories";
    searchQuery = "";
    if (lastActiveDir) {
      const idx = directories.findIndex((d) => d.name === lastActiveDir);
      if (idx !== -1) selectedIndex = idx;
      else selectedIndex = 0;
    } else {
      selectedIndex = 0;
    }
    await loadDirectories();
    if (lastActiveDir) {
      const idx = directories.findIndex((d) => d.name === lastActiveDir);
      if (idx !== -1) selectedIndex = idx;
    }
  }
  function showSettingsView() {
    currentView = "settings";
    searchQuery = "";
  }
  async function useItem(item) {
    if (!item) return;
    try {
      await invoke("toggle_main_window");
      setTimeout(async () => {
        await invoke("paste_text", { text: item.content });
      }, 50);
    } catch (err) {
      console.error("Failed to paste text:", err);
    }
  }
  async function createFolder(event) {
    const name = event.detail;
    if (!name) return;
    try {
      await invoke("create_directory", { name });
      await loadDirectories();
    } catch (err) {
      console.error("Failed to create folder:", err);
    }
  }
  function deleteDirectory(name) {
    openModal({
      title: "Delete Folder",
      message: `Are you sure you want to delete folder "${name}"? All items inside will be lost.`,
      isDanger: true,
      confirmText: "Delete",
      onConfirm: async () => {
        try {
          await invoke("delete_directory", { name });
          await loadDirectories();
        } catch (err) {
          console.error("Failed to delete folder:", err);
        }
      },
    });
  }
  function renameDirectory(oldName) {
    openModal({
      title: "Rename Folder",
      message: "Enter new name for the folder:",
      showInput: true,
      inputValue: oldName,
      confirmText: "Rename",
      onConfirm: async (newName) => {
        if (!newName || newName === oldName) return;
        try {
          await invoke("rename_directory", { oldName, newName });
          await loadDirectories();
        } catch (err) {
          console.error("Failed to rename folder:", err);
        }
      },
    });
  }
  function startEdit(item) {
    if (!item) return;
    editingId = item.id;
    editContent = item.content;
    editMemo = item.memo || "";
    if (item.directory) currentDirId = item.directory;
  }
  async function saveEdit() {
    try {
      await invoke("update_history_item", {
        id: editingId,
        content: editContent,
        directory: currentDirId,
        memo: editMemo || null,
      });
      editingId = null;
      await loadHistory();
      await loadDirectories();
    } catch (err) {
      console.error("Failed to update item:", err);
    }
  }
  async function createItem(event) {
    const { content, memo } = event.detail;
    if (!content) return;
    try {
      await invoke("create_history_item", {
        content,
        directory: currentDirId,
        memo,
      });
      await loadHistory();
      await loadDirectories();
    } catch (err) {
      console.error("Failed to create item:", err);
    }
  }
  function deleteItem(id) {
    openModal({
      title: "Delete Item",
      message: "Are you sure you want to delete this item?",
      isDanger: true,
      confirmText: "Delete",
      onConfirm: async () => {
        try {
          await invoke("delete_history_item", { id });
          await loadHistory();
          await loadDirectories();
        } catch (err) {
          console.error("Failed to delete item:", err);
        }
      },
    });
  }
  // --- Vertical resize (Rust-side mouse polling) ---
  const MIN_HEIGHT = 300;
  const MAX_HEIGHT = 1400;
  const WINDOW_WIDTH = 380;

  function startResize(e) {
    e.preventDefault();
    document.body.style.cursor = "ns-resize";
    invoke("start_height_resize");
    window.addEventListener("mouseup", stopResize, { once: true });
  }

  async function stopResize() {
    document.body.style.cursor = "";
    const height = await invoke("stop_height_resize");
    if (height > 0) {
      localStorage.setItem("windowHeight", String(height));
    }
  }
  // --- End vertical resize ---

  let directoryView;
  let itemView;
  let searchView;
  let header;
  function handleKeyDown(event) {
    resetAutoHideTimer();
    const isInput =
      event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA";
    const isSearchInput = event.target.classList.contains("header-search");
    if (event.key === "Escape") {
      if (modalConfig.show) {
        closeModal();
        return;
      }
      if (detailItem !== null) {
        detailItem = null;
        return;
      }
      if (editingId !== null) {
        editingId = null;
        return;
      }
      if (currentView === "settings") {
        showDirectoryView();
        return;
      }
      if (isSearchInput || searchQuery) {
        searchQuery = "";
        if (isSearchInput) {
          event.target.blur(); 
        }
        return;
      }
      invoke("toggle_main_window");
      return;
    }
    if (modalConfig.show) {
      if (isInput) {
        if (event.key === "Enter") {
          event.preventDefault();
          return;
        }
        return;
      }
      if (event.key === "Enter") {
        event.preventDefault();
        return;
      }
      event.preventDefault();
      return;
    }
    if (detailItem !== null && event.key !== "Escape") {
      return;
    }
    if (editingId !== null && isInput) {
      if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
        saveEdit();
        return;
      }
    }
    if (!isInput && !event.metaKey && !event.ctrlKey && !event.altKey) {
      if (event.key.length === 1 || event.key === "Backspace") {
        if (header) header.focusSearch();
      }
    }
    let listCount = 0;
    if (searchQuery) {
      listCount = filteredDirectories.length + globalFilteredItems.length;
    } else if (currentView === "directories") {
      listCount = filteredDirectories.length + 1;
    } else {
      listCount = filteredItems.length + 1;
    }
    const isSpecialKey = event.metaKey || event.ctrlKey;
    if (!isInput || isSearchInput) {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        if (listCount > 0) {
          selectedIndex = (selectedIndex + 1) % listCount;
        }
        return;
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        if (listCount > 0) {
          selectedIndex = (selectedIndex - 1 + listCount) % listCount;
        }
        return;
      } else if (
        searchQuery &&
        !isSearchInput &&
        (event.key === "ArrowRight" || event.key === "ArrowLeft")
      ) {
        event.preventDefault();
        if (searchView) searchView.handleArrowKey(event.key);
        return;
      } else if (
        !searchQuery &&
        (event.key === "ArrowRight" || event.key === "ArrowLeft")
      ) {
        if (currentView === "items" && itemView) {
          const handled = itemView.handleArrowKey(event.key);
          if (handled) {
            event.preventDefault();
            return;
          }
        }
        if (event.key === "ArrowRight") {
          if (currentView === "directories") {
            const dir = filteredDirectories[selectedIndex];
            if (dir) {
              event.preventDefault();
              showItemView(dir.name);
              if (isSearchInput) event.target.blur();
            }
          }
        } else if (event.key === "ArrowLeft") {
          if (currentView === "items") {
            event.preventDefault();
            showDirectoryView();
            if (isSearchInput) event.target.blur();
          } else if (currentView === "settings") {
            event.preventDefault();
            showDirectoryView();
          }
        }
        return;
      }
    }
    if (isSearchInput && event.key === "Enter") {
      event.preventDefault();
      if (searchQuery) {
        if (searchView) searchView.executeSelectedAction();
      } else if (currentView === "directories") {
        const filtered = filteredDirectories;
        if (selectedIndex < filtered.length) {
          showItemView(filtered[selectedIndex].name);
        }
      } else if (currentView === "items" && itemView) {
        itemView.executeSelectedAction();
      }
      return;
    }
    if (isInput) return;
    const activeFiltered = searchQuery
      ? [...filteredDirectories, ...globalFilteredItems]
      : currentView === "directories"
        ? filteredDirectories
        : filteredItems;
    if (event.key === "Backspace" && isSpecialKey) {
      event.preventDefault();
      if (activeFiltered[selectedIndex]) {
        if (searchQuery) {
          if (selectedIndex < filteredDirectories.length) {
            deleteDirectory(activeFiltered[selectedIndex].name);
          } else {
            deleteItem(activeFiltered[selectedIndex].id);
          }
        } else if (currentView === "directories") {
          deleteDirectory(activeFiltered[selectedIndex].name);
        } else {
          deleteItem(activeFiltered[selectedIndex].id);
        }
      }
    } else if (event.key === " " && currentView === "items" && !searchQuery) {
      event.preventDefault();
      if (activeFiltered[selectedIndex])
        handleView(activeFiltered[selectedIndex]);
    } else if (event.key === "Enter" && !searchQuery) {
      event.preventDefault();
      if (currentView === "directories") {
        const dir = filteredDirectories[selectedIndex];
        if (dir) {
          showItemView(dir.name);
        } else if (selectedIndex === filteredDirectories.length) {
          if (directoryView) directoryView.handleCreate();
        }
      } else if (currentView === "items" && itemView) {
        itemView.executeSelectedAction();
      }
    }
  }
</script>
<svelte:window on:keydown={handleKeyDown} />
<div
  on:mousemove={resetAutoHideTimer}
  class="w-full h-full max-h-screen bg-bg-container rounded-[16px] border border-white/10 flex flex-col overflow-hidden relative shadow-[0_8px_24px_rgba(0,0,0,0.5)] {isVisible
    ? 'opacity-100'
    : 'opacity-0 transition-opacity duration-[350ms] ease-out pointer-events-none'} {modalConfig.show ||
  detailItem !== null
    ? 'pointer-events-none'
    : 'pointer-events-auto'}"
>
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    class="absolute bottom-0 left-0 right-0 h-3 flex items-end justify-center pb-[3px] cursor-ns-resize z-50 group"
    on:mousedown={startResize}
  >
    <div class="w-8 h-[3px] rounded-full bg-white/10 group-hover:bg-white/30 transition-colors duration-150"></div>
  </div>

  <div class="flex flex-col h-full pb-3">
    <Header
      bind:this={header}
      title={searchQuery
        ? "Search results"
        : currentView === "settings"
          ? "Settings"
          : currentView === "directories"
            ? "PasteSheet"
            : currentDirId}
      showBack={(currentView === "items" || currentView === "settings") &&
        !searchQuery}
      bind:searchQuery
      on:back={showDirectoryView}
      on:settings={showSettingsView}
    />
    <div class="h-px bg-white/10 flex-shrink-0"></div>
    <div class="flex-1 overflow-hidden relative px-4 py-1">
      {#if searchQuery}
        <div class="absolute inset-0" transition:fly={{ y: 10, duration: 150 }}>
          <SearchView
            bind:this={searchView}
            {filteredDirectories}
            filteredItems={globalFilteredItems}
            bind:selectedIndex
            bind:editingId
            bind:editContent
            bind:editMemo
            on:openFolder={(e) => showItemView(e.detail)}
            on:paste={(e) => useItem(e.detail)}
            on:edit={(e) => startEdit(e.detail)}
            on:delete={(e) => deleteItem(e.detail)}
            on:save={saveEdit}
            on:cancel={() => (editingId = null)}
            on:view={(e) => handleView(e.detail)}
          />
        </div>
      {:else if currentView === "directories"}
        <div
          class="absolute inset-0"
          transition:fly={{ x: -10, duration: 150 }}
        >
          <DirectoryView
            bind:this={directoryView}
            directories={filteredDirectories}
            bind:selectedIndex
            on:open={(e) => showItemView(e.detail)}
            on:rename={(e) => renameDirectory(e.detail)}
            on:delete={(e) => deleteDirectory(e.detail)}
            on:create={createFolder}
          />
        </div>
      {:else if currentView === "items"}
        <div class="absolute inset-0">
          <ItemView
            bind:this={itemView}
            historyItems={filteredItems}
            bind:selectedIndex
            bind:editingId
            bind:editContent
            bind:editMemo
            on:back={showDirectoryView}
            on:paste={(e) => useItem(e.detail)}
            on:edit={(e) => startEdit(e.detail)}
            on:delete={(e) => deleteItem(e.detail)}
            on:save={saveEdit}
            on:cancel={() => (editingId = null)}
            on:create={createItem}
            on:view={(e) => handleView(e.detail)}
          />
        </div>
      {:else if currentView === "settings"}
        <div class="absolute inset-0" transition:fly={{ y: 10, duration: 150 }}>
          <SettingsView on:back={showDirectoryView} on:settingschange={handleSettingsChange} />
        </div>
      {/if}
    </div>
  </div>
</div>
<Modal
  show={modalConfig.show}
  title={modalConfig.title}
  message={modalConfig.message}
  confirmText={modalConfig.confirmText}
  cancelText={modalConfig.cancelText}
  isDanger={modalConfig.isDanger}
  showInput={modalConfig.showInput}
  bind:inputValue={modalConfig.inputValue}
  on:confirm={handleModalConfirm}
  on:cancel={closeModal}
/>
<DetailModal
  show={detailItem !== null}
  content={detailItem ? detailItem.content : ""}
  on:close={closeDetail}
/>
