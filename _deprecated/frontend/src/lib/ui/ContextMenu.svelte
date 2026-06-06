<script>
  import { createEventDispatcher, onMount } from "svelte";
  import { fade, scale } from "svelte/transition";
  export let x = 0;
  export let y = 0;
  export let options = [];
  const dispatch = createEventDispatcher();
  function handleClickOutside(event) {
    if (!event.target.closest(".context-menu")) {
      dispatch("close");
    }
  }
  function handleOptionClick(option) {
    dispatch("select", option.action);
    dispatch("close");
  }
  function handleKeydown(event) {
    if (event.key === "Escape") {
      dispatch("close");
    }
  }
</script>
<svelte:window on:click={handleClickOutside} on:keydown={handleKeydown} />
<div
  class="context-menu fixed z-[9999] min-w-[120px] bg-[#1e1e1e] border border-white/10 rounded-lg shadow-xl p-1 overflow-hidden"
  style="top: {y}px; left: {x}px;"
  transition:scale={{ duration: 100, start: 0.95 }}
>
  {#each options as option}
    <button
      class="w-full text-left px-3 py-2 rounded text-xs font-medium transition-colors flex items-center justify-between
      {option.danger
        ? 'text-red-400 hover:bg-red-500/10'
        : 'text-text-main hover:bg-white/10'}"
      on:click|stopPropagation={() => handleOptionClick(option)}
    >
      {option.label}
    </button>
  {/each}
</div>
