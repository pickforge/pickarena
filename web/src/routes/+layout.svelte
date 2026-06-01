<script lang="ts">
  import '../app.css';

  let { children } = $props();
</script>

<svelte:head>
  <title>Dart Arena by Pickforge</title>
  <meta
    name="description"
    content="Dart Arena by Pickforge benchmarks AI coding models on Dart and Flutter engineering tasks."
  />
</svelte:head>

{@render children()}
