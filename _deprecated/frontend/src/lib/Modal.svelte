<script>
  import { createEventDispatcher, onMount } from "svelte";
  import { fade, scale } from "svelte/transition";
  export let show = false;
  export let title = "Confirm";
  export let message = "";
  export let confirmText = "Confirm";
  export let cancelText = "Cancel";
  export let isDanger = false;
  export let showInput = false;
  export let inputValue = "";
  const dispatch = createEventDispatcher();
  let confirmBtn;
  let cancelBtn;
  $: if (show && confirmBtn && !showInput) {
    setTimeout(() => confirmBtn.focus(), 50);
  }
  function handleConfirm() {
    dispatch("confirm", showInput ? inputValue : true);
  }
  function handleCancel() {
    dispatch("cancel");
  }
  function autofocus(node) {
    node.focus();
  }
  function handleKeydown(e) {
    if (!show) return;
    if (e.key === "Escape") {
      e.preventDefault();
      e.stopPropagation();
      handleCancel();
    }
    if (e.key === "Enter") {
      if (e.target.tagName === "INPUT" && e.target !== document.activeElement)
        return;
      e.preventDefault();
      e.stopPropagation();
      handleConfirm();
    }
    if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
      const activeElement = document.activeElement;
      if (
        activeElement?.tagName === "INPUT" ||
        activeElement?.tagName === "TEXTAREA"
      ) {
        return; 
      }
      e.preventDefault();
      e.stopPropagation();
      if (activeElement === confirmBtn && cancelBtn) {
        cancelBtn.focus();
      } else if (activeElement === cancelBtn && confirmBtn) {
        confirmBtn.focus();
      }
    }
  }
</script>
<svelte:window on:keydown|capture={handleKeydown} />
{#if show}
  <div
    class="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
    transition:fade={{ duration: 200 }}
    on:click|self={handleCancel}
  >
    <div
      class="bg-bg-container border border-white/10 rounded-2xl p-6 w-full max-w-sm shadow-2xl"
      transition:scale={{ duration: 200, start: 0.95 }}
    >
      <h3 class="text-lg font-bold text-accent mb-2">{title}</h3>
      <p class="text-text-main/90 text-sm mb-6 leading-relaxed">
        {message}
      </p>
      {#if showInput}
        <input
          type="text"
          class="w-full bg-black/30 border border-white/10 rounded-lg px-3 py-2 text-text-main mb-6 outline-none focus:border-accent transition-all"
          bind:value={inputValue}
          use:autofocus
          spellcheck="false"
        />
      {/if}
      <div class="flex justify-end gap-3">
        <button
          bind:this={cancelBtn}
          class="px-4 py-2 rounded-lg bg-white/5 text-text-main text-sm font-medium hover:bg-white/10 transition-all outline-none focus:bg-white/20 focus:scale-105"
          on:click={handleCancel}
        >
          {cancelText}
        </button>
        <button
          bind:this={confirmBtn}
          class="px-4 py-2 rounded-lg text-sm font-bold transition-all outline-none {isDanger
            ? 'bg-red-500 text-white hover:bg-red-600 shadow-[0_4px_12px_rgba(239,68,68,0.3)] focus:bg-red-450 focus:scale-105 focus:shadow-[0_6px_24px_rgba(239,68,68,0.6)]'
            : 'bg-accent text-bg-app hover:brightness-110 shadow-[0_4px_12px_rgba(220,220,87,0.3)] focus:brightness-125 focus:scale-105 focus:shadow-[0_6px_24px_rgba(220,220,87,0.6)]'}"
          on:click={handleConfirm}
        >
          {confirmText}
        </button>
      </div>
    </div>
  </div>
{/if}
