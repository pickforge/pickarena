# Dart Arena by Pickforge — Master Spec

## Goal

Create a Bun/Svelte static landing page for publishing Dart Arena benchmark results under the Pickforge brand, while keeping the Flutter/Dart app as the benchmark runner and source of truth.

## Product direction

- Public name: **Dart Arena by Pickforge**
- Positioning: a benchmark for comparing AI coding models on Dart and Flutter engineering tasks.
- Visual identity: Pickforge near-black geometric shapes, orange dot accent, white/near-white canvas, bracket/dot motif from `pickforge_mark.png`.

## Target architecture

```txt
dart_arena/
  .factory/
  .github/
  .vscode/
  package.json
  bun.lock

  app/
    .factory/
    pubspec.yaml
    lib/
    bin/
    test/
    assets/
    linux/
    macos/
    windows/

  web/
    .factory/
    package.json
    src/
    static/
      branding/
      data/
        leaderboard.v1.json
```

The Flutter app moves into `app/` to avoid collision with Svelte's `web/` directory. The Dart package/import name remains `dart_arena`.

## Data source and contract

The public site must not read the Drift/sqlite database directly. The database remains an internal runner store; the site consumes a generated, versioned static JSON file.

```txt
Flutter/headless benchmark runner
  -> Drift/sqlite database
  -> Dart export CLI
  -> web/static/data/leaderboard.v1.json
  -> Svelte static site
```

Add a Dart executable such as:

```sh
cd app
dart run dart_arena:dart_arena_export_leaderboard \
  --database .dart_arena/dart_arena.sqlite \
  --out ../web/static/data/leaderboard.v1.json \
  --strategy aggregate-compatible
```

Supported export strategies:

- `aggregate-compatible` default: aggregate all compatible task runs matching the selected filters.
- `latest-run`: export only the latest completed run, useful for local preview.
- `best-observed`: optional/labeled mode only; never the public default because it can look cherry-picked.

## Aggregation semantics

Default public leaderboard uses `aggregate-compatible`.

Compatibility filters:

- same benchmark track, e.g. `codegen` or `agentic`
- same task IDs and task versions
- same harness/scoring schema
- same evaluator weights when applicable
- selected provider/model variants only

Model rows should be grouped by provider, model, and effort/config variant when present. The default score is aggregate primary pass rate across compatible samples, not the best single run.

Metrics should reuse existing analytics where possible:

- pass rate
- Wilson confidence interval
- task-run/sample count
- solved count
- median latency
- median prompt tokens
- median completion tokens
- median estimated cost
- cost per solved task
- failure breakdown

## `leaderboard.v1.json` shape

Initial public contract:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-05-31T00:00:00.000Z",
  "benchmark": {
    "name": "Dart Arena",
    "brand": "Pickforge",
    "title": "Dart Arena by Pickforge",
    "track": "agentic",
    "dataPolicy": "aggregate-compatible"
  },
  "source": {
    "runIds": [],
    "taskCount": 0,
    "taskRunCount": 0
  },
  "models": [],
  "tasks": []
}
```

Do not include provider secrets, raw prompts, hidden verifier content, private local paths, or full model responses in the public JSON.

## Svelte landing page

Use Bun + Svelte/SvelteKit as a static site under `web/`.

Core sections:

1. Header with Pickforge mark and **Dart Arena by Pickforge**
2. Hero with benchmark summary and primary CTA
3. Key metrics cards
4. Pass-rate vs cost/time scatter plot
5. Ranked model table
6. Task examples
7. Methodology/provenance section
8. Footer with Pickforge branding

The first implementation should be static and data-driven from `leaderboard.v1.json`. Add richer interactivity only after the contract is stable.

## Branding assets

Use:

- `pickforge_logo.png`
- `pickforge_mark.png`

During the monorepo migration, keep canonical Flutter assets under `app/assets/branding/` and copy the public web-safe assets into `web/static/branding/`. A shared root branding folder can be introduced later if duplication becomes a problem.

## Execution slices

1. **Monorepo migration**
   - Move Flutter project files into `app/`.
   - Add root Bun workspace metadata.
   - Update CI, IDE paths, `.gitignore`, and validation commands.

2. **Leaderboard export CLI**
   - Add Dart executable for `leaderboard.v1.json`.
   - Reuse existing Drift DB access and analytics helpers.
   - Add tests for grouping, filtering, and JSON shape.

3. **Svelte/Bun scaffold**
   - Create `web/`.
   - Add Svelte static build setup.
   - Load sample `leaderboard.v1.json`.

4. **Landing page UI**
   - Implement Pickforge-styled page sections.
   - Add responsive layout and accessible tables/charts.

5. **Validation and polish**
   - Run app and web validators.
   - Fix migration fallout.
   - Confirm static build output.

## Validation

App validation:

```sh
cd app
flutter pub get
dart format --set-exit-if-changed lib test bin
flutter analyze
flutter test
```

Web validation:

```sh
cd web
bun install
bun run check
bun run build
```

Root validation should eventually expose convenience scripts:

```sh
bun run check
bun run build
```

## Risks and decisions

- Moving the Flutter project into `app/` is path-heavy and should be its own implementation slice.
- Public aggregation must avoid cherry-picking; default to compatible aggregate results.
- The export contract should be versioned from the start to avoid tying the web app to DB schema migrations.
- Hidden verifier data and raw model outputs must stay out of public site data by default.
- Existing untracked local files should not be moved or removed unless explicitly requested.
