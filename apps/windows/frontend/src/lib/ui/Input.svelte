<script>
  export let value = "";
  export let placeholder = "";
  export let type = "text";
  export let className = "";
  export let autofocus = false;
  export let spellcheck = false;
  let inputRef;
  $: if (autofocus && inputRef) {
    inputRef.focus();
  }
  export function focus() {
    if (inputRef) inputRef.focus();
  }
  export function blur() {
    if (inputRef) inputRef.blur();
  }
</script>
<input
  bind:this={inputRef}
  {type}
  {placeholder}
  {spellcheck}
  bind:value
  class="bg-black/30 border border-white/10 rounded-lg px-3 py-2 text-text-main outline-none focus:border-accent transition-all {className}"
  on:input
  on:keydown
  on:blur
  on:focus
/>
