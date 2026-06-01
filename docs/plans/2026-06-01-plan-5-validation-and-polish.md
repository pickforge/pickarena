# Plan 5 — Validation and Polish

## Goal

Add a lightweight validation and polish pass for the Svelte static landing page so the first public web slice is easier to trust, preview, and maintain before deployment work.

## Success criteria

- Static build output is checked by a committed smoke script.
- The landing page passes Svelte type checks and static build.
- The page is manually validated at desktop and mobile sizes with Playwright or browser automation.
- Core navigation anchors work: `#leaderboard`, `#tasks`, and `#methodology`.
- No visible raw `undefined`, `[object Object]`, or unintended `null` strings appear in the built page.
- Generated build output and local browser artifacts remain ignored.
- No Flutter app behavior, export CLI behavior, or `leaderboard.v1.json` contract changes are introduced.
- Existing user-owned untracked files such as `deepswe-full.png` remain untouched.

## Current context

- Plan 4 implemented the first full Pickforge-styled landing page under `web/`.
- The web package already has:
  - `check`: `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json`
  - `build`: `vite build`
  - `preview`: `vite preview`
- The root package already has:
  - `web:check`
  - `web:build`
  - `check`
  - `build`
- Build output is generated under `web/build/` and ignored.
- Playwright MCP is available in the Droid environment for manual validation, but the repository does not currently depend on Playwright.

## Proposed changes

### 1. Add static-output smoke validation

Create:

```txt
web/scripts/smoke-static.ts
```

The script should run after `bun run build` and validate the generated static output in `web/build/`.
Resolve paths from the `web/` package root or from `import.meta.url` so the script works when invoked as `bun run scripts/smoke-static.ts` from `web/`; report paths in repo-relative form for clarity.

Checks:

- `web/build/index.html` exists.
- `web/build/data/leaderboard.v1.json` exists and parses as JSON.
- required branding assets exist under `web/build/branding/`.
- generated HTML includes the important section anchors:
  - `id="leaderboard"`
  - `id="tasks"`
  - `id="methodology"`
- generated HTML includes the expected public title text `Dart Arena by Pickforge`.
- visible generated HTML text does not include obvious unresolved rendering artifacts after excluding script/style/template content and markup:
  - `undefined`
  - `[object Object]`
  - unintended standalone `null`
- generated HTML includes references to SvelteKit client assets under `_app/`.

Keep the script dependency-free and runnable with Bun.

### 2. Wire smoke validation into scripts

Update:

```txt
web/package.json
package.json
```

Add web script:

```json
{
  "smoke": "bun run build && bun run scripts/smoke-static.ts"
}
```

Add root script:

```json
{
  "web:smoke": "cd web && bun run smoke"
}
```

Do not add the smoke script to root `check` if it materially slows local validation. It is acceptable to keep root `check` as analyze/tests/typecheck and run `web:smoke` separately for release/web validation.

### 3. Small responsive and accessibility polish

Update only if inspection or browser validation confirms the need:

```txt
web/src/app.css
web/src/routes/+page.svelte
```

Allowed polish:

- improve responsive metric-card grid sizing so cards do not become cramped at medium widths;
- refine header/nav wrapping on narrow screens;
- ensure SVG chart has a stable aspect ratio and remains readable;
- ensure decorative imagery has correct `alt=""` or meaningful alt text;
- ensure warning/provenance text does not duplicate confusingly;
- improve table overflow behavior without hiding content.

Do not redesign the page or add new sections.

### 4. Manual Playwright/browser QA

Use existing browser automation rather than adding Playwright as a package dependency.

Procedure:

1. Run `bun run web:build`.
2. Start a local preview server with `cd web && bun run preview -- --host 127.0.0.1`.
3. Use Playwright/browser automation to validate:
   - desktop viewport around `1440x900`;
   - mobile viewport around `390x844`;
   - page loads without console errors;
   - no unexpected horizontal page scroll on mobile except table overflow inside the table wrapper;
   - header/hero are visible;
   - anchor links move to `#leaderboard`, `#tasks`, and `#methodology`;
   - accessibility snapshot exposes sensible headings/links/table content.

Do not commit screenshots or browser artifacts unless explicitly requested.

### 5. Keep scope focused

Out of scope:

- deployment configuration;
- CI workflow changes;
- image snapshot baselines;
- adding Playwright, Axe, Lighthouse, or visual-regression dependencies;
- changing exporter behavior or sample JSON schema;
- adding interactive sorting/filtering controls;
- polishing beyond first-pass layout fixes discovered by validation.

## Files touched

Expected new files:

```txt
web/scripts/smoke-static.ts
```

Expected modified files:

```txt
package.json
web/package.json
```

Possibly modified if browser validation finds concrete layout/accessibility issues:

```txt
web/src/app.css
web/src/routes/+page.svelte
```

Not expected:

```txt
app/**
web/static/data/leaderboard.v1.json
web/static/branding/**
docs/specs/**
```

## Validation

Run after implementation:

```sh
cd web
bun run check
bun run build
bun run smoke
```

Run from repository root:

```sh
bun run web:check
bun run web:build
bun run web:smoke
bun run check
```

Manual/browser validation:

```sh
cd web
bun run preview -- --host 127.0.0.1
```

Then use Playwright/browser automation for the desktop and mobile checks listed above.

Verify source control state:

```sh
git status --porcelain
git diff --stat
```

If any `app/` file changes unexpectedly, stop and inspect. Only then run:

```sh
cd app
flutter analyze
flutter test
```

## Risks and mitigations

- **Smoke checks too brittle:** assert stable structural output only; avoid relying on hashed asset names or full HTML snapshots.
- **Preview server left running:** run it in a managed background process and stop it after Playwright validation.
- **Browser artifacts accidentally committed:** keep screenshots/traces out of git unless explicitly requested.
- **Scope creep:** fix only concrete validation issues found by smoke/browser checks.
- **False confidence from static checks:** keep `bun run check`, `bun run build`, `bun run web:smoke`, and browser QA as separate evidence.
- **Untracked local files:** keep `deepswe-full.png` untracked and untouched.
