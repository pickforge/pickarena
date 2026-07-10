<script lang="ts">
  let {
    title,
    code
  }: {
    title: string;
    code: string;
  } = $props();

  let copied = $state(false);
  let timer: ReturnType<typeof setTimeout> | undefined;

  async function copy() {
    try {
      await navigator.clipboard.writeText(code);
      copied = true;
      clearTimeout(timer);
      timer = setTimeout(() => (copied = false), 1600);
    } catch (error) {
      copied = false;
    }
  }
</script>

<div class="code-block">
  <div class="code-block-head">
    <span class="code-block-title">{title}</span>
    <button type="button" class="copy-btn" class:copied onclick={copy}>
      {copied ? 'Copied' : 'Copy'}
    </button>
  </div>
  <pre><code>{code}</code></pre>
</div>
