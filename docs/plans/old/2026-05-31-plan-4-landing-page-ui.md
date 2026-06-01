# Plan 4 — Landing Page UI

## Goal

Replace the scaffold-only Svelte route with the first complete Pickforge-styled Dart Arena landing page, driven by `leaderboard.v1.json` and suitable for static publishing.

## Success criteria

- The page includes the master-spec sections:
  - header with Pickforge mark and Dart Arena by Pickforge;
  - hero with benchmark summary and primary CTA;
  - key metric cards;
  - pass-rate vs cost/time visualization;
  - ranked model table;
  - task examples;
  - methodology/provenance section;
  - footer with Pickforge branding.
- The UI is responsive, accessible, and usable with the current sample JSON and future exported `leaderboard.v1.json` files.
- The implementation uses existing SvelteKit/Bun setup and does not add chart/table dependencies unless strictly necessary.
- Static build output remains generated-only and ignored.
- The Flutter app, export CLI, and JSON export contract remain unchanged.
- Existing user-owned untracked files such as `deepswe-full.png` remain untouched.

## Current context

- Plan 3 created the SvelteKit static scaffold under `web/`.
- `web/src/routes/+layout.ts` prerenders static output and loads leaderboard data.
- `web/src/lib/data/leaderboard.ts` exposes a minimal typed loader with fallback warnings.
- `web/src/routes/+page.svelte` currently renders a simple scaffold view.
- `web/static/data/leaderboard.v1.json` contains a small safe sample fixture.
- Branding assets are available under:

```txt
web/static/branding/
```

## Proposed changes

### 1. Strengthen public leaderboard types for UI use

Update:

```txt
web/src/lib/data/leaderboard.ts
```

Add typed row shapes for the fields used by the UI:

- model rows:
  - `providerId`
  - `modelId`
  - `rank`
  - `score`
  - `passRate`
  - `passCount`
  - `sampleCount`
  - `confidenceInterval.lower`
  - `confidenceInterval.upper`
  - `lowSample`
  - `medianLatencyMs`
  - `medianPromptTokens`
  - `medianCompletionTokens`
  - `medianEstimatedCostMicros`
  - `costPerSolvedTaskMicros`
  - `failureBreakdown`
- task rows:
  - `taskId`
  - `taskVersion`
  - `benchmarkTrack`
  - `sampleCount`
  - `modelCount`
  - `passRate`
- source:
  - `anchorRunId` as `string | null`
  - `runIds`
  - `taskCount`
  - `taskRunCount`
  - `modelCount`
  - `warnings`

Rewrite `parseLeaderboard` so model and task arrays are mapped through typed row parsers that extract the fields above. Keep parsing tolerant: unknown, missing, or malformed optional metrics should become `null`, `false`, `[]`, or `{}` as appropriate rather than failing the whole page. Treat missing or non-string `source.anchorRunId` as `null`. Continue to fail only when the required scaffold fields are missing.

### 2. Add small presentation helpers

Create:

```txt
web/src/lib/data/format.ts
```

Helpers should format:

- percentages from `0.0`-to-`1.0` ratios;
- integer counts;
- generated timestamps/dates, with `unknown` for null or invalid values;
- milliseconds as seconds/minutes;
- token counts;
- micro-USD costs as `$x.xx`, with `unknown` for null;
- model display names as `provider / model`.

Keep these helpers dependency-free and unit-free in naming so they are easy to use in Svelte templates.

### 3. Replace scaffold route with landing page sections

Update:

```txt
web/src/routes/+page.svelte
```

Implement the first complete static landing page:

1. **Header**
   - Pickforge mark/logo.
   - `Dart Arena by Pickforge`.
   - Anchor links to `#leaderboard`, `#tasks`, and `#methodology`.

2. **Hero**
   - Headline: benchmark AI coding models on Dart and Flutter engineering tasks.
   - Short explanation that Dart Arena uses a Dart/Flutter runner and static public exports.
   - CTA linking to `#leaderboard`.
   - Secondary CTA or link to `#methodology`.
   - Surface any loader/source warning with `role="alert"`.

3. **Key metrics**
   - Models, tasks, task runs, data policy, generated timestamp.
   - Derived summary from available rows:
     - top model pass rate;
     - lowest known cost per solved task;
     - median latency for top model when available.

4. **Pass-rate vs efficiency visualization**
   - Dependency-free responsive SVG or CSS visualization.
   - If using SVG, include a `viewBox`, render at `width: 100%`, and preserve a fixed aspect ratio.
   - Plot model pass rate against known `costPerSolvedTaskMicros`.
   - If cost is missing for all models, fall back to pass rate vs `medianLatencyMs`.
   - Include accessible text/table fallback content.
   - Do not imply statistical precision beyond available samples.

5. **Ranked model table**
   - Section id: `leaderboard`.
   - Show rank, model, pass rate, confidence interval, samples, median latency, median cost, cost per solved task, and low-sample flag.
   - Sort by exported rank when present; otherwise preserve parsed order.
   - Render empty state if no model rows exist.

6. **Task examples**
   - Section id: `tasks`.
   - Show a handful of task rows sorted by sample count/pass rate.
   - Include task ID, version, track, pass rate, model count, sample count.
   - Render empty state if no task rows exist.

7. **Methodology/provenance**
   - Section id: `methodology`.
   - Explain `aggregate-compatible`, static JSON export, versioned schema, and why best-observed is not the default.
   - Show source run count, anchor run ID, task run count, and source warnings; render a missing anchor run ID as `unknown` or `none`, not raw `null`.
   - Avoid exposing raw prompts, hidden verifier content, responses, patches, or local paths.

8. **Footer**
   - Pickforge branding.
   - Static-data/version note.

### 4. Move page styling into shared CSS

Update:

```txt
web/src/app.css
web/src/routes/+layout.svelte
```

Use Pickforge-inspired styling:

- near-black text/geometric surfaces;
- warm off-white background;
- orange accent dot/bracket motif;
- large editorial hero typography;
- responsive card grid;
- accessible focus states;
- table styles with horizontal overflow on small screens;
- reduced-motion-friendly transitions only if any are used.

Avoid global CSS that would make future components difficult to style.

### 5. Keep implementation dependency-light

Do not add charting libraries, table libraries, UI frameworks, or runtime schema libraries in this plan.

Only change `bun.lock` if existing package metadata changes unexpectedly. The preferred implementation should not need new dependencies.

## Files touched

Expected modified files:

```txt
web/src/app.css
web/src/lib/data/leaderboard.ts
web/src/routes/+layout.svelte
web/src/routes/+page.svelte
```

Expected new file:

```txt
web/src/lib/data/format.ts
```

Possibly modified only if implementation reveals a necessary script/dependency adjustment:

```txt
web/package.json
bun.lock
package.json
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
```

Run from repository root:

```sh
bun run web:check
bun run web:build
bun run check
```

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

- **Over-polishing:** keep the page complete but first-pass; defer rich filtering, sorting controls, and animation polish.
- **Misleading metrics:** label sample counts, low-sample rows, confidence intervals, and data policy clearly.
- **Missing optional fields:** tolerate null costs/latencies/tokens and show `unknown` instead of zero.
- **Chart accessibility:** provide text/table fallback and labels, not only visual dots.
- **Static build regressions:** keep prerendered SvelteKit behavior unchanged and validate with `bun run build`.
- **Scope creep into export contract:** do not modify the Dart exporter or sample JSON shape in this plan.
- **Untracked local files:** keep `deepswe-full.png` untracked and untouched.
