<script>
  export let type = "button";
  export let variant = "secondary"; 
  export let size = "md"; 
  export let className = "";
  export let disabled = false;
  const variants = {
    primary: "bg-accent text-black hover:brightness-110",
    secondary:
      "bg-white/10 text-text-main hover:bg-white/20 border border-white/10",
    danger:
      "bg-red-500/20 text-red-500 hover:bg-red-500/30 border border-red-500/10",
    ghost: "bg-transparent text-text-sub hover:text-text-main hover:bg-white/5",
  };
  const sizes = {
    sm: "px-3 py-1 text-xs font-bold rounded",
    md: "px-4 py-2 text-sm font-medium rounded-lg",
    lg: "px-6 py-3 text-base font-bold rounded-xl",
  };
</script>
<button
  {type}
  {disabled}
  class="{sizes[size]} {variants[
    variant
  ]} transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed {className}"
  on:click
>
  <slot />
</button>
