<script lang="ts">
  import '../app.css';
  import type { Snippet } from 'svelte';
  import { base } from '$app/paths';
  import { page } from '$app/state';
  import { browser } from '$app/environment';
  import type { LayoutData } from './$types';

  let { data, children }: { data: LayoutData; children: Snippet } = $props();

  const pickforgeMarkSrc = `${base}/branding/pickforge_mark.png`;
  const leaderboard = $derived(data.leaderboard);

  const navItems = [
    { href: `${base}/`, label: 'Leaderboard', match: (p: string) => p === `${base}/` },
    {
      href: `${base}/methodology`,
      label: 'Methodology',
      match: (p: string) => p.startsWith(`${base}/methodology`)
    },
    {
      href: `${base}/tasks`,
      label: 'Tasks',
      match: (p: string) => p.startsWith(`${base}/tasks`)
    },
    { href: `${base}/run`, label: 'Run', match: (p: string) => p.startsWith(`${base}/run`) }
  ];

  let theme = $state<'light' | 'dark'>('dark');

  $effect(() => {
    if (!browser) return;
    const stored = localStorage.getItem('pickarena-theme');
    if (stored === 'light' || stored === 'dark') {
      theme = stored;
    } else {
      theme = window.matchMedia('(prefers-color-scheme: light)').matches
        ? 'light'
        : 'dark';
    }
  });

  function toggleTheme() {
    theme = theme === 'dark' ? 'light' : 'dark';
    document.documentElement.dataset.theme = theme;
    try {
      localStorage.setItem('pickarena-theme', theme);
    } catch (error) {
      /* ignore persistence failures */
    }
  }
</script>

<div class="shell">
  <header class="site-header">
    <a class="brand-lockup" href={`${base}/`} aria-label="PickArena by Pickforge Studio home">
      <img src={pickforgeMarkSrc} alt="" width="32" height="32" />
      <span>PickArena<span class="brand-sub">&nbsp;· Pickforge Studio</span></span>
    </a>

    <div class="header-right">
      <nav class="nav-links" aria-label="Primary">
        {#each navItems as item}
          <a href={item.href} class:active={item.match(page.url.pathname)}>{item.label}</a>
        {/each}
      </nav>
      <button
        type="button"
        class="theme-toggle"
        onclick={toggleTheme}
        aria-label="Toggle color theme"
        title="Toggle color theme"
      >
        {#if theme === 'dark'}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <circle cx="12" cy="12" r="4" />
            <path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" />
          </svg>
        {:else}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z" />
          </svg>
        {/if}
      </button>
    </div>
  </header>

  {#if data.warning}
    <p class="warning" role="alert">
      <strong>Data unavailable.</strong> {data.warning} The metrics below may be empty until
      a valid export is published.
    </p>
  {:else if leaderboard.models.length === 0}
    <p class="warning" role="alert">
      <strong>No results yet.</strong> This export contains no model rows. Run and publish a
      benchmark to populate the leaderboard.
    </p>
  {/if}

  {#if leaderboard.provisional}
    <div class="provisional-banner" role="status">
      <strong>Provisional</strong>
      <span>
        This board reflects a single interim run of one model. Treat every number as a
        preview, not a ranking, until the v1.0 corpus run publishes.
      </span>
    </div>
  {/if}

  <main class="page">
    {@render children()}
  </main>

  <footer class="site-footer">
    <div class="footer-brand">
      <img src={pickforgeMarkSrc} alt="" width="24" height="24" />
      <span>Pickforge Studio</span>
    </div>
    <div class="footer-links">
      <a href={`${base}/`}>Leaderboard</a>
      <a href={`${base}/methodology`}>Methodology</a>
      <a href={`${base}/tasks`}>Tasks</a>
      <a href={`${base}/run`}>Run</a>
      <a href="https://pickforge.dev">pickforge.dev</a>
    </div>
    <span class="muted">Static export · leaderboard.v{leaderboard.schemaVersion}</span>
  </footer>
</div>
