<script lang="ts">
  import '../app.css';

  let { children } = $props();
</script>

<svelte:head>
  <title>PickArena by Pickforge Studio</title>
  <meta
    name="description"
    content="PickArena by Pickforge Studio benchmarks AI coding models on Dart and Flutter engineering tasks."
  />
</svelte:head>

{@render children()}
