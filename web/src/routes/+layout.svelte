<script lang="ts">
  import '../app.css';

  let { children } = $props();
</script>

<svelte:head>
  <title>Dart Arena by Pickforge</title>
  <meta
    name="description"
    content="Dart Arena by Pickforge benchmark scaffold"
  />
</svelte:head>

{@render children()}
