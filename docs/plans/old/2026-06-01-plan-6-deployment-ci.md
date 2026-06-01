# Plan 6 — Web CI and Deployment Readiness

## Goal

Make the Pickforge/Dart Arena static web landing page continuously validated and deployment-ready from `main`, without changing benchmark execution or the public leaderboard export contract.

## Success criteria

- GitHub Actions validates both the Flutter benchmark app and the Svelte static web app.
- Web CI runs Bun install, Svelte checks, static build, and static smoke validation.
- The static web app works when hosted at a root domain or a non-root deployment base path.
- CI/deployment does not require provider API keys, local SQLite databases, or private benchmark artifacts.
- Build artifacts, `.svelte-kit/`, and `web/build/` remain uncommitted.
- Existing `leaderboard.v1.json` sample data remains the deployed data source for this slice.
- Provider-specific deployment wiring remains deferred until Vercel or another host is selected.

## Current context

- Root scripts already include:
  - `web:check`
  - `web:build`
  - `web:smoke`
  - `check`
- `web/scripts/smoke-static.ts` validates the static build output, public data JSON, required branding assets, core anchors, SvelteKit assets, and obvious rendering artifacts.
- `.github/workflows/ci.yml` currently validates only the Flutter/headless path.
- The web app currently assumes root hosting for URLs such as `/data/leaderboard.v1.json` and `/branding/dart_arena_mark.png`.
- `leaderboard:export` depends on a local read-only SQLite database, so CI should not generate public data in this slice.
- GitHub Pages deployment was deferred because repository Pages is not enabled and the likely deployment target is Vercel or another host.

## Proposed changes

### 1. Add base-path-safe static asset and data URLs

Update the web app so it can be built for either:

- root hosting, such as a custom domain; or
- non-root hosting, such as `/dart_arena`.

Use SvelteKit base path support rather than hard-coded absolute URLs.

Expected approach:

- Configure `kit.paths.base` from `process.env.PUBLIC_BASE_PATH ?? ''` in `web/svelte.config.js`.
- Set `kit.paths.relative` to `false` so `_app`, `%sveltekit.assets%`, and `$app/paths` output are deterministic root/base-prefixed URLs for smoke validation.
- Replace hard-coded static asset URLs and root-relative app links in Svelte source with URLs based on `$app/paths` `base`, including the home link currently rendered as `href="/"`.
- Replace the favicon URL in `web/src/app.html` with `%sveltekit.assets%/branding/dart_arena_mark.png`; do not use `$app/paths` in `app.html`.
- Fetch leaderboard data from `${base}/data/leaderboard.v1.json`.
- In base-path builds, rendered HTML should not contain root-relative app URLs such as `href="/"`, `src="/branding/...`, or `data-url="/data/...`; section-only anchors such as `href="#leaderboard"` remain valid.

Do not change `leaderboard.v1.json` structure or contents.

### 2. Extend static smoke validation for base paths

Update `web/scripts/smoke-static.ts` so it validates the current build mode:

- default root build still passes for root/custom-domain hosting;
- a non-empty `PUBLIC_BASE_PATH` build includes base-prefixed references for `_app`, `data`, `branding`, and the base-aware home link;
- a non-empty `PUBLIC_BASE_PATH` build rejects root-relative rendered app URLs for internal links, static assets, and data fetches while allowing section-only anchors;
- physical files still exist under `web/build/`.

Keep the smoke script dependency-free.

### 3. Add a web CI job

Update `.github/workflows/ci.yml` with a separate web job:

- install Bun with `oven-sh/setup-bun`;
- run `bun install --frozen-lockfile`;
- run `bun run web:check`;
- run `bun run web:smoke`.

Keep the existing Flutter/headless job intact.
This job validates the default root/custom-domain build mode. The `/dart_arena` build mode remains covered by local smoke validation until a deployment provider is selected.

### 4. Keep deployment provider wiring deferred

Do not add a GitHub Pages deployment job in this slice.

The repo should remain ready for a later provider-specific deployment by keeping `PUBLIC_BASE_PATH` configurable and smoke-validating a non-root base path locally/when needed. Vercel or another host can be wired in a later plan once the target is chosen.

### 5. Keep data publishing out of scope

Do not run `bun run leaderboard:export` in CI for this slice.

Official result publishing should be a separate plan because it needs an intentional source for the benchmark SQLite database or a trusted generated artifact.

## Files touched

Expected modified files:

```txt
.github/workflows/ci.yml
web/svelte.config.js
web/src/app.html
web/src/lib/data/leaderboard.ts
web/src/routes/+page.svelte
web/scripts/smoke-static.ts
```

Possibly modified if script aliases need tightening:

```txt
package.json
web/package.json
```

Not expected:

```txt
app/lib/**
app/test/**
web/static/data/leaderboard.v1.json
web/static/branding/**
docs/specs/**
```

## Validation

Run before implementation to confirm the current baseline:

```sh
bun run web:check
bun run web:smoke
bun run check
```

Run after implementation:

```sh
bun run web:check
bun run web:smoke
PUBLIC_BASE_PATH=/dart_arena bun run web:smoke
bun run check
```

Inspect the generated HTML for base path correctness:

```sh
PUBLIC_BASE_PATH=/dart_arena bun run web:smoke
rg '"/dart_arena/(_app|data|branding)|href="/dart_arena/"|data-url="/dart_arena/data/' web/build/index.html
rg 'href="/"|src="/branding/|href="/branding/|data-url="/data/' web/build/index.html && exit 1 || true
```

Verify source control state:

```sh
git status --porcelain
git diff --stat
```

## Risks and mitigations

- **Deployment base path breaks assets:** validate both root and `/dart_arena` builds with smoke checks.
- **Custom-domain mismatch:** keep `PUBLIC_BASE_PATH` configurable; document in the workflow comments only if needed.
- **CI time increases:** split Flutter/headless and web jobs so failures are isolated and jobs can run in parallel.
- **Accidental data publishing:** deploy committed sample/public JSON only; leave official data refresh for a later plan.
- **Secrets exposure:** do not add provider keys or database credentials to CI.
- **Unsupported deployment target:** avoid adding a deployment job until the target host is selected and configured.
