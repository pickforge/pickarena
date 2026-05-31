# Plan 1 — Monorepo Migration

## Goal

Move the existing Flutter/Dart benchmark app into `app/` and prepare the repository root for the future Bun/Svelte `web/` package, without changing benchmark behavior or starting the web implementation.

## Success criteria

- Flutter app runs from `app/`.
- Dart package/import name remains `dart_arena`.
- Existing headless executable still works from `app/`.
- CI and VS Code launch configuration point at `app/`.
- Root is ready for later `web/` work.
- Existing untracked user-owned files are not moved, deleted, or overwritten.

## Current context

- Flutter project files currently live at repository root.
- Existing CI workflow: `.github/workflows/ci.yml`.
- Existing VS Code launch config: `.vscode/launch.json`.
- Existing untracked files/directories include `.factory/`, `.playwright-mcp/`, and `deepswe-full.png`.
- A full app format check currently reports four pre-existing fixture files that would reformat; this migration should not fix unrelated fixture formatting.

## Proposed changes

### 1. Move Flutter app files into `app/`

Move tracked app-owned paths:

```txt
analysis_options.yaml -> app/analysis_options.yaml
assets/               -> app/assets/
bin/                  -> app/bin/
lib/                  -> app/lib/
linux/                -> app/linux/
macos/                -> app/macos/
test/                 -> app/test/
windows/              -> app/windows/
pubspec.yaml          -> app/pubspec.yaml
pubspec.lock          -> app/pubspec.lock
.metadata             -> app/.metadata
```

Use `git mv` only for tracked files. For `linux/`, `macos/`, and `windows/`, inspect ignored/untracked descendants before moving and avoid whole-directory moves that would carry generated platform outputs with stale root paths.

Keep these at root:

```txt
.factory/
.github/
.vscode/
.gitignore
README.md
LICENSE
docs/
MODELS.md
opencode_go_efforts.md
```

Do not move generated/local-only paths:

```txt
.dart_tool/
.flutter-plugins-dependencies
build/
linux/flutter/ephemeral/
linux/flutter/generated_plugin_registrant.*
linux/flutter/generated_plugins.cmake
macos/Flutter/ephemeral/
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/ephemeral/
windows/flutter/generated_plugin_registrant.*
windows/flutter/generated_plugins.cmake
dart_arena.iml
.playwright-mcp/
deepswe-full.png
.worktrees/
```

### 2. Add root Bun/package metadata

Create a root `package.json` with app-oriented scripts only. Do not scaffold Svelte yet.

Planned scripts:

```json
{
  "private": true,
  "scripts": {
    "app:pub": "cd app && flutter pub get",
    "app:analyze": "cd app && flutter analyze",
    "app:test": "cd app && flutter test",
    "app:headless": "cd app && dart run --verbosity=error dart_arena:dart_arena_headless",
    "check": "bun run app:analyze && bun run app:test"
  }
}
```

Add workspaces only when `web/package.json` exists in Plan 3, to avoid a dangling workspace target.

### 3. Update path references

Update root files that assume the Flutter app is at repository root:

- `.github/workflows/ci.yml`
  - Run `flutter pub get`, `dart format`, `dart run`, `flutter analyze`, and `flutter test` with `working-directory: app`.
  - Remove the existing root-only `.github/workflows` argument from the `dart format` command; keep only app-relative Dart paths such as `bin`, `lib/core`, `lib/export`, `lib/headless`, `lib/runner`, `lib/storage`, `test/core`, `test/headless`, `test/runner`, and `test/support`.
- `.vscode/launch.json`
  - Add `"cwd": "app"` to Dart launch configurations.
- `.gitignore`
  - Preserve existing ignores.
  - Update the lockfile exception from `!/pubspec.lock` to `!/app/pubspec.lock`.
- `README.md`
  - Update image paths to `app/assets/...`.
  - Update commands to `cd app` before Flutter/Dart commands.

### 4. Preserve package behavior

- Do not rename the Dart package.
- Do not edit imports.
- Do not alter benchmark tasks, storage, analytics, or provider behavior.
- Do not add the Svelte app yet.

## Files touched

Expected:

```txt
package.json
.github/workflows/ci.yml
.vscode/launch.json
.gitignore
README.md
app/**
```

Not expected:

```txt
lib/**
test/**
bin/**
assets/**
```

The original root paths above should disappear only because they were moved into `app/`.

## Validation

Run after migration:

```sh
cd app
flutter pub get
flutter analyze
flutter test
dart run --verbosity=error dart_arena:dart_arena_headless --help
```

On Linux hosts, also verify the moved desktop platform files build from `app/`:

```sh
cd app
flutter build linux --debug
```

Run root script check if Bun is installed:

```sh
bun run check
```

For formatting, run a scoped check that avoids unrelated fixture churn:

```sh
cd app
dart format --output=none --set-exit-if-changed bin lib/core lib/export lib/headless lib/runner lib/storage test/core test/headless test/runner test/support
```

## Risks and mitigations

- **Path-heavy migration:** use `git mv` for tracked paths and inspect `git status --short` before/after.
- **Generated artifacts:** do not move root `.dart_tool`, `build`, `.flutter-plugins-dependencies`, or ignored/generated platform descendants; regenerate under `app/` with `flutter pub get` or the desktop build.
- **Untracked user files:** do not delete/move `.playwright-mcp/`, `deepswe-full.png`, or `.worktrees/`.
- **CI path regressions:** update workflow commands to use `working-directory: app`.
- **VS Code launch regression:** set launch `cwd` to `app`.
- **Formatting noise:** avoid broad formatter cleanup in this plan; keep behavior-only validation focused on analyze/tests/headless CLI.

## Out of scope

- Svelte/SvelteKit scaffold.
- `leaderboard.v1.json` export CLI.
- Web branding implementation.
- Benchmark aggregation changes.
- Public deployment setup.
