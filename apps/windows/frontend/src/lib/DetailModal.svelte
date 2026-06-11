<script>
  import { createEventDispatcher } from "svelte";
  import { fade, scale } from "svelte/transition";
  import Button from "./ui/Button.svelte";
  export let show = false;
  export let content = "";
  export let title = "Detail View";
  const dispatch = createEventDispatcher();
  function handleClose() {
    dispatch("close");
  }
  function handleCopy() {
    navigator.clipboard
      .writeText(content)
      .then(() => {
        dispatch("copy");
      })
      .catch((err) => {
        console.error("Failed to copy", err);
        dispatch("copy");
      });
  }
  function handleKeydown(event) {
    if (!show) return;
    if (event.key === "Escape") {
      handleClose();
    }
  }
</script>
<svelte:window on:keydown={handleKeydown} />
{#if show}
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
    transition:fade={{ duration: 200 }}
    on:click={handleClose}
    on:keydown={(e) => e.key === "Escape" && handleClose()}
    role="button"
    tabindex="-1"
  >
    <div
      class="bg-[#1e1e1e] border border-white/10 rounded-xl shadow-2xl w-[90%] max-w-3xl max-h-[80vh] flex flex-col overflow-hidden"
      transition:scale={{ duration: 200, start: 0.95 }}
      on:click|stopPropagation={() => {}}
      on:keydown|stopPropagation={() => {}}
      role="dialog"
      aria-modal="true"
      aria-label={title}
      tabindex="-1"
    >
      <div
        class="flex items-center justify-between p-4 border-b border-white/10 bg-white/5"
      >
        <h2 class="text-lg font-bold text-text-main truncate">{title}</h2>
        <div class="flex gap-2">
          <Button size="sm" variant="primary" on:click={handleCopy}>Copy</Button
          >
          <Button size="sm" variant="secondary" on:click={handleClose}
            >Close</Button
          >
        </div>
      </div>
      <div class="flex-1 p-6 overflow-y-auto bg-[#1a1a1a]">
        <pre
          class="text-text-sub text-sm font-mono whitespace-pre-wrap break-words leading-relaxed">{content}</pre>
      </div>
    </div>
  </div>
{/if}
