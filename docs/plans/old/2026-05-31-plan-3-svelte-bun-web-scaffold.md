# Plan 3 — Svelte/Bun Web Scaffold

## Goal

Create the initial `web/` package for a Bun-powered SvelteKit static site that can consume `leaderboard.v1.json`, without implementing the full landing page UI yet.

## Success criteria

- A new `web/` package exists and can be installed, checked, and statically built with Bun.
- The site is configured for static output and can be served from generated files.
- The web package loads `static/data/leaderboard.v1.json` through normal static asset fetches.
- Pickforge/Dart Arena branding assets needed by the web app are present under `web/static/branding/`.
- Root scripts know how to run app and web validation together.
- The Flutter app, export CLI, and existing benchmark behavior remain unchanged.
- The implementation avoids deleting or moving user-owned untracked files such as `deepswe-full.png`.

## Current context

- The Flutter/Dart app now lives in `app/`.
- The repository root has a Bun `package.json` with app-only scripts:
  - `app:pub`
  - `app:analyze`
  - `app:test`
  - `app:headless`
  - `check`
- Plan 2 added `dart_arena_export_leaderboard`, which can generate a public-safe `leaderboard.v1.json`.
- The expected web data path from the master spec is:

```txt
web/static/data/leaderboard.v1.json
```

- Branding assets currently live in:

```txt
app/assets/branding/
```

- There is no `web/` package yet.

## Proposed changes

### 1. Create a minimal SvelteKit package under `web/`

Create a Bun/SvelteKit package using TypeScript and static adapter output.

Expected structure:

```txt
web/
  package.json
  svelte.config.js
  tsconfig.json
  vite.config.ts
  src/
    app.html
    app.css
    lib/
      data/
        leaderboard.ts
    routes/
      +layout.ts
      +layout.svelte
      +page.svelte
  static/
    branding/
    data/
      leaderboard.v1.json
```

Use SvelteKit with `@sveltejs/adapter-static` so Plan 4 can focus on UI rather than build plumbing.

Configure static output explicitly:

- use `@sveltejs/adapter-static` in `svelte.config.js`;
- add `web/src/routes/+layout.ts` with `export const prerender = true;` so `bun run build` emits static files without requiring a server runtime.

Keep the first route intentionally simple:

- fetch or import the static leaderboard JSON;
- render a small scaffold page proving data can load;
- show the Dart Arena by Pickforge title;
- show basic generated/source counts from `leaderboard.v1.json`;
- avoid implementing the final hero, charts, ranked table, or methodology sections in this plan.

### 2. Add a typed leaderboard loader

Create:

```txt
web/src/lib/data/leaderboard.ts
```

Responsibilities:

- Define minimal TypeScript types for the existing `leaderboard.v1.json` contract.
- Load `/data/leaderboard.v1.json` from static assets.
- Validate only the small set of fields needed for scaffold rendering:
  - `schemaVersion`
  - `benchmark.title`
  - `benchmark.track`
  - `benchmark.dataPolicy`
  - `source.taskCount`
  - `source.taskRunCount`
  - `models`
  - `tasks`
- Return a safe empty fallback plus a visible warning if the static JSON is missing or malformed.

Do not introduce a runtime schema library in this plan unless the generated scaffold already includes one; keep dependency footprint small.

### 3. Add sample static leaderboard data

Create:

```txt
web/static/data/leaderboard.v1.json
```

Use a small fixture matching schema version `1`.

The fixture should:

- be safe to publish;
- contain no provider secrets, raw prompts, responses, patches, local absolute paths, or hidden verifier details;
- include enough data for the scaffold route to prove rendering works;
- be clearly replaceable by the export CLI.

Add a root script for generating or refreshing the file from a local DB, but do not require a local DB for normal web checks/builds.

Suggested root script:

```json
{
  "leaderboard:export": "cd app && dart run --verbosity=error dart_arena:dart_arena_export_leaderboard --database .dart_arena/dart_arena.sqlite --out ../web/static/data/leaderboard.v1.json --track agentic"
}
```

### 4. Copy web-safe branding assets

Copy only web-needed public assets from `app/assets/branding/` to:

```txt
web/static/branding/
```

Minimum assets:

```txt
pickforge_logo.png
pickforge_mark.png
dart_arena_logo_horizontal_light.png
dart_arena_logo_horizontal_dark.png
dart_arena_mark.png
```

Keep `app/assets/branding/` as the Flutter app source. Do not introduce a shared branding package in this plan.

### 5. Update Bun scripts, workspace metadata, and ignores

Update root `package.json` to include `web` as a workspace and expose web commands.

Define `web/package.json` scripts used by the root scripts:

```json
{
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json"
  }
}
```

Include only the SvelteKit dependencies needed by this scaffold, including `@sveltejs/kit`, `@sveltejs/adapter-static`, `@sveltejs/vite-plugin-svelte`, `svelte`, `vite`, `typescript`, and `svelte-check`.

Expected scripts:

```json
{
  "scripts": {
    "app:pub": "cd app && flutter pub get",
    "app:analyze": "cd app && flutter analyze",
    "app:test": "cd app && flutter test",
    "app:headless": "cd app && dart run --verbosity=error dart_arena:dart_arena_headless",
    "web:install": "cd web && bun install",
    "web:dev": "cd web && bun run dev",
    "web:check": "cd web && bun run check",
    "web:build": "cd web && bun run build",
    "leaderboard:export": "cd app && dart run --verbosity=error dart_arena:dart_arena_export_leaderboard --database .dart_arena/dart_arena.sqlite --out ../web/static/data/leaderboard.v1.json --track agentic",
    "check": "bun run app:analyze && bun run app:test && bun run web:check",
    "build": "bun run web:build"
  },
  "workspaces": ["web"]
}
```

Update the root `.gitignore` by appending web-specific generated-output ignores and Bun lockfile exceptions after the existing `*.lock` rule:

```gitignore
node_modules/
.svelte-kit/
web/build/
!/bun.lock
!/web/bun.lock
```

If Bun creates a root `bun.lock`, commit it. If Bun creates only `web/bun.lock`, commit that instead. Do not commit generated build output.

### 6. Keep Plan 4 UI work out of scope

Plan 3 should not implement the full visual design.

Out of scope:

- final Pickforge landing page layout;
- hero polish;
- scatter plots;
- ranked model table UX;
- responsive chart interactions;
- deployment configuration;
- screenshots or visual regression tests;
- changing the Dart export contract.

## Files touched

Expected new files:

```txt
web/package.json
web/svelte.config.js
web/tsconfig.json
web/vite.config.ts
web/src/app.html
web/src/app.css
web/src/lib/data/leaderboard.ts
web/src/routes/+layout.ts
web/src/routes/+layout.svelte
web/src/routes/+page.svelte
web/static/data/leaderboard.v1.json
web/static/branding/pickforge_logo.png
web/static/branding/pickforge_mark.png
web/static/branding/dart_arena_logo_horizontal_light.png
web/static/branding/dart_arena_logo_horizontal_dark.png
web/static/branding/dart_arena_mark.png
```

Expected modified files:

```txt
.gitignore
package.json
```

Expected generated lockfile, depending on Bun behavior:

```txt
bun.lock
```

or:

```txt
web/bun.lock
```

Not expected:

```txt
app/lib/**
app/test/**
app/bin/**
app/pubspec.yaml
app/pubspec.lock
README.md
docs/specs/**
```

## Validation

Run after implementation:

```sh
cd web
bun install
bun run check
bun run build
```

Run from the root:

```sh
bun run web:check
bun run web:build
bun run check
```

Verify `git status --porcelain` after validation and confirm new implementation changes are limited to expected files, generated build output is ignored, and existing user-owned untracked files such as `deepswe-full.png` remain untouched.

Also verify the export CLI can still print help from the app:

```sh
cd app
dart run --verbosity=error dart_arena:dart_arena_export_leaderboard --help
```

Full Flutter tests are not required for this scaffold-only plan unless app files change unexpectedly; if any `app/` source, test, or pubspec file changes, run:

```sh
cd app
flutter analyze
flutter test
```

## Risks and mitigations

- **SvelteKit generator drift:** prefer a minimal explicit scaffold or inspect generated files before committing; remove template demo code that is not needed.
- **Static adapter misconfiguration:** ensure `adapter-static` is configured and `bun run build` emits static output without requiring a server runtime.
- **Data fetch path issues:** use `/data/leaderboard.v1.json` so the built static site resolves the JSON from `web/static/data/`.
- **Dependency churn:** keep web dependencies limited to SvelteKit, Vite, TypeScript, check tooling, and static adapter.
- **Accidental app changes:** this plan should not touch app code; if tooling updates app files, stop and inspect before continuing.
- **Branding duplication:** duplicate only public web-safe assets for now; defer shared asset package design until duplication becomes painful.
- **Untracked local files:** keep `deepswe-full.png` untracked unless the user explicitly asks to commit or remove it.
