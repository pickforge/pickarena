# Open Source Release Polish Implementation Plan

> **Status:** Draft plan.
> **Goal:** make Dart Arena presentable and buildable as an open-source desktop app.

## Goal

Polish Dart Arena for public release with clear branding, build metadata, README onboarding, MIT licensing, and desktop app presentation.

## Success criteria

- Visible app/window titles use `Dart Arena`, not `dart_arena`.
- The Dart package/import name remains `dart_arena` to avoid unnecessary code churn.
- The provided Dart Arena logo is committed under stable branding assets and used for README and desktop icons.
- Pickforge logos are committed only as README/footer brand assets; Pickforge does not replace the Dart Arena app/product name.
- README is rewritten for open-source onboarding, setup, validation, build, privacy, and contribution workflows.
- MIT `LICENSE` exists.
- Linux, Windows, and macOS metadata are presentable for local builds.
- Existing benchmark behavior, database paths, provider IDs, and package imports are unchanged.

## Branding decisions

- Product/app name: `Dart Arena`.
- Package name: keep `dart_arena`.
- Pickforge usage: README footer only.
- License: MIT.
- Main app logo source: `assets/branding/dart_arena_logo.png`.
- Pickforge assets:
  - `assets/branding/pickforge_mark.png`
  - `assets/branding/pickforge_logo.png`

## Task 1: Asset placement and icon generation

- [ ] Keep copied source assets in `assets/branding/`.
- [ ] Register only `assets/branding/dart_arena_logo.png` in `pubspec.yaml` for in-app use.
- [ ] Do not bundle Pickforge assets into Flutter unless the app UI uses them.
- [ ] Generate desktop icons from `assets/branding/dart_arena_logo.png`:
  - macOS `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png`;
  - Windows `windows/runner/resources/app_icon.ico`;
  - optional Linux PNG under `linux/runner/resources/app_icon.png` only if wired cleanly.
- [ ] Preserve `macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, or update it if generated icon filenames/sizes change.
- [ ] Use local image tooling (`magick` if available) to crop/resize/compress as needed.

## Task 2: App naming and platform metadata

- [ ] Update `pubspec.yaml` description to a real project description.
- [ ] Add branding asset path to `pubspec.yaml`.
- [ ] Update Flutter UI title surfaces:
  - `lib/app.dart` `MaterialApp.router(title: 'Dart Arena')`;
  - dashboard app bar title to `Dart Arena`.
- [ ] Update Linux desktop title strings in `linux/runner/my_application.cc`.
- [ ] Keep Linux binary name and application ID stable unless changing them is necessary for presentation.
- [ ] Update Windows title in `windows/runner/main.cpp`.
- [ ] Update Windows resource metadata in `windows/runner/Runner.rc`:
  - `CompanyName`: `Dart Arena contributors`;
  - `FileDescription`: `Dart Arena`;
  - `ProductName`: `Dart Arena`;
  - keep internal/original executable names stable;
  - copyright: `Copyright (C) 2026 Dart Arena contributors`.
- [ ] Update macOS app name/copyright:
  - `macos/Runner/Configs/AppInfo.xcconfig` `PRODUCT_NAME = Dart Arena`;
  - copyright to Dart Arena contributors;
  - add `CFBundleDisplayName` in `macos/Runner/Info.plist` if not already present.

## Task 3: README and license

- [ ] Replace current model-recommendations README with open-source onboarding.
- [ ] Include Dart Arena logo at the top.
- [ ] Explain:
  - what Dart Arena is;
  - codegen vs agentic tracks;
  - hidden verifiers/task QA;
  - repeated trials/reliable leaderboard;
  - human review;
  - provenance/export bundles;
  - headless CI smoke.
- [ ] Add quick start, provider setup, run/test/build commands, privacy/security notes, contributing notes, and MIT license note.
- [ ] Add Pickforge footer only, using a relative image link to `assets/branding/pickforge_logo.png`.
- [ ] Add `LICENSE` with MIT text and `Copyright (c) 2026 Dart Arena contributors`.

## Task 4: Release hygiene

- [ ] Verify no generated build outputs or local secrets are added.
- [ ] Keep untracked source images in the main checkout untouched; work only from the release worktree copies.
- [ ] Do not rename the package, database filename, import paths, or provider IDs in this pass.
- [ ] Do not add store packaging, installers, signing, or release automation.

## Validation

Required:

```sh
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build linux --debug
```

Best-effort, only if available on the host:

```sh
file assets/branding/*.png
file windows/runner/resources/app_icon.ico
file macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png
flutter build windows --debug
flutter build macos --debug
```

## Risks and mitigations

- **Windows/macOS builds may not be runnable on Linux.** Update metadata and icons, then validate with analyzer/tests and Linux build; document platform-build commands in README.
- **Icon generation can degrade quality.** Use the high-resolution Dart Arena logo as source and inspect generated file metadata.
- **Over-renaming can break imports/storage.** Keep package name, binary name, database path, and IDs stable unless explicitly changed later.
- **Pickforge brand ambiguity.** Keep Pickforge as README footer only for this pass.
