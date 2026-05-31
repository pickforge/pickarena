# TMPDIR Bootstrap & Cache Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `/tmp` (a 16 GB tmpfs on CachyOS) from being filled by `dart`, `flutter`, and `droid` subprocesses spawned during benchmark runs by redirecting their `TMPDIR` to a disk-backed folder under the app-support dir, and add a small cache manager that prevents unbounded growth and exposes a manual "Clear cache" action in Settings.

**Architecture:**
- On app startup (before any subprocess can spawn), mutate the live OS env via `dart:ffi` (`setenv("TMPDIR", "<appSupport>/tmp", 1)` on POSIX; `SetEnvironmentVariableW` on Windows) so child processes started later through `Process.run` inherit the app-managed tmp path automatically.
- A `TmpDirManager` owns the configured path. On startup it sweeps stale/oversized entries. It exposes `currentSize()` and `clear()` for the Settings UI.
- A new section in `SettingsPage` shows the current cache size and a "Clear cache" button.

**Tech Stack:** Dart `dart:ffi` (libc `setenv` on Linux/macOS, `SetEnvironmentVariableW` on Windows), `path_provider` (already a dep), `ffi` package (new direct dep — `^2.1.0`, already resolves transitively to `2.2.0` with the current `sdk: ^3.11.4` lockfile).

**Platform support:** Linux + macOS via libc `setenv("TMPDIR", ...)`. Windows via `kernel32.dll` `SetEnvironmentVariableW` for `TMP`, `TEMP`, and `TMPDIR` (most Windows tools read `TMP`/`TEMP`, while setting `TMPDIR` is harmless for POSIX-oriented subprocesses). The bootstrap function is a no-op if the native lookup fails (defensive — never block app startup). On macOS sandboxed builds, `getApplicationSupportDirectory()` returns the app container's writable support dir, so this remains inside the sandbox; subprocess execution itself is an existing app capability and is not changed by this plan.

**Environment semantics:** On POSIX, Dart has no supported API to mutate the current process env; `Platform.environment` is a cached/unmodifiable Dart view and must not be used for this. Calling libc `setenv` mutates the process `environ`, and later `Process.run` / `Process.start` calls with no explicit `environment:` inherit that live OS env. This plan intentionally overwrites any inherited `TMPDIR` for app-spawned subprocesses so benchmark runs use the app-managed disk-backed path deterministically.

---

## File Structure

- Create `lib/runner/tmpdir_bootstrap.dart`: FFI wrapper that mutates the parent process env for `TMPDIR`.
- Create `lib/runner/tmpdir_manager.dart`: cache directory, size accounting, sweep policy, manual clear.
- Modify `lib/main.dart`: build the tmp dir path, bootstrap env, instantiate manager, run startup sweep, pass manager to `App`.
- Modify `lib/app.dart`: expose `TmpDirManager` via `RepositoryProvider` so the Settings page can read it.
- Modify `lib/ui/pages/settings_page.dart`: add a `_CacheSection` widget showing size + Clear cache button.
- Modify `pubspec.yaml`: add `ffi: ^2.1.0` dependency.
- Tests:
  - Create `test/runner/tmpdir_manager_test.dart`: covers `currentSize`, `sweep` (age + size thresholds), `clear`.
  - `tmpdir_bootstrap.dart` is **not unit-tested directly** (it mutates real process env and depends on FFI). Document this in a header comment.

---

## Task 1: Add `ffi` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] Add under `dependencies:` block (alphabetical placement near `file_picker`):

```yaml
  ffi: ^2.1.0
```

- [ ] Run `dart pub get` (or `flutter pub get`) and verify it resolves cleanly.

---

## Task 2: TMPDIR bootstrap via FFI

**Files:**
- Create: `lib/runner/tmpdir_bootstrap.dart`

- [ ] Implement a single public function:

```dart
/// Mutates the current process's OS env so that `TMPDIR` points at [path]
/// (and `TMP`/`TEMP` on Windows).
/// Child processes started afterwards via `Process.run`/`Process.start`
/// inherit this value. Creates [path] if missing. Safe no-op on platforms
/// where the native symbol cannot be resolved.
///
/// NOTE: This is intentionally untested at unit-test level: it mutates
/// the real running process env via dart:ffi. It is exercised manually
/// by launching the app and verifying that spawned subprocesses see
/// the new TMPDIR.
void bootstrapTmpDir(String path);
```

- [ ] Import `package:ffi/ffi.dart` for `Utf8`, `Utf16`, `toNativeUtf8`, `toNativeUtf16`, and allocation/free helpers.
- [ ] On Linux/macOS: `DynamicLibrary.process()` + `lookupFunction` for `setenv(const char*, const char*, int)` returning `int`. Call with `overwrite = 1`. Free both `Pointer<Utf8>` allocations afterwards.
- [ ] On Windows: `DynamicLibrary.open('kernel32.dll')` + `SetEnvironmentVariableW(LPCWSTR, LPCWSTR)` returning non-zero success. Set `TMP`, `TEMP`, and `TMPDIR`. Free every `Pointer<Utf16>` allocation afterwards.
- [ ] Always `Directory(path).createSync(recursive: true)` before calling the libc function.
- [ ] Wrap the FFI lookup + call in `try { ... } catch (_) { /* no-op */ }` so a missing symbol never blocks app startup. Do not log to stderr in production — debug-only `assert(() { print(...); return true; }())` is acceptable.

---

## Task 3: `TmpDirManager` cache manager

**Files:**
- Create: `lib/runner/tmpdir_manager.dart`

- [ ] Public surface:

```dart
class TmpDirManager {
  TmpDirManager({required this.root, this.maxAge = const Duration(days: 7), this.maxBytes = 2 * 1024 * 1024 * 1024});

  final Directory root;
  final Duration maxAge;
  final int maxBytes;

  /// Total size of [root] in bytes (recursive). Returns 0 if [root] is missing.
  Future<int> currentSize();

  /// Deletes top-level children of [root] whose mtime is older than [maxAge].
  /// Then, if total size still exceeds [maxBytes], deletes oldest top-level
  /// children until under the budget. Errors on individual entries are
  /// swallowed so one bad file does not block the sweep.
  Future<void> sweep();

  /// Removes every top-level child of [root]. [root] itself is recreated empty.
  Future<void> clear();
}
```

- [ ] `currentSize` walks the tree via `Directory.list(recursive: true, followLinks: false)` and sums only real files (`entity is File`). Skip dirs and symlinks so a symlink inside the cache never causes size accounting to escape `root`.
- [ ] `sweep` first ensures `root` exists, then snapshots **top-level** entries only (don't recurse into pub-cache subdirs to decide age — the top-level entries are what dart/flutter/droid create per invocation). Use `entity.statSync().modified` for age. Keep a `startedAt = DateTime.now()` cutoff and never delete an entry whose mtime is after `startedAt`, so a benchmark that starts while the fire-and-forget sweep is still running is not targeted.
- [ ] After age pass, if `currentSize() > maxBytes`, sort the remaining snapshotted top-level entries by mtime ascending and delete oldest until under the budget, still skipping entries modified after `startedAt`.
- [ ] All deletions: `entity.delete(recursive: true)` wrapped in `try { ... } catch (_) {}`. Per-entry failure must not abort the sweep.
- [ ] `clear`: `await root.delete(recursive: true)` then `await root.create(recursive: true)`. If `root` does not exist, just create it.

---

## Task 4: Wire into `main.dart`

**Files:**
- Modify: `lib/main.dart`

- [ ] After `getApplicationSupportDirectory()`, before `runApp`:

```dart
final tmpRoot = Directory(p.join(supportDir.path, 'tmp'))
  ..createSync(recursive: true);
bootstrapTmpDir(tmpRoot.path);
final tmpDirManager = TmpDirManager(root: tmpRoot);
unawaited(tmpDirManager.sweep()); // fire-and-forget, must not delay app launch
```

- [ ] Pass `tmpDirManager` to `App(...)`. Add `import 'dart:async';` for `unawaited`.
- [ ] Order matters: `bootstrapTmpDir` MUST be called **before** any `Process.run` site. In the current `lib/main.dart`, `AppDatabase()` only constructs a Drift `LazyDatabase`, `getApplicationSupportDirectory()` is a platform-channel lookup, and `SettingsRepository()` does not spawn subprocesses; all existing `Process.run` sites are reached later from runner/provider/evaluator code after UI interaction. Placing the bootstrap immediately after `supportDir` resolution is therefore correct.

---

## Task 5: Wire `TmpDirManager` through the widget tree

**Files:**
- Modify: `lib/app.dart`

- [ ] Add `required this.tmpDirManager` to `App` constructor.
- [ ] Register `RepositoryProvider<TmpDirManager>.value(value: tmpDirManager)` in the `MultiRepositoryProvider` list, alongside the existing `WorkdirManager` provider.

---

## Task 6: Settings UI — cache section

**Files:**
- Modify: `lib/ui/pages/settings_page.dart`

- [ ] Add a new `_CacheSection` `StatefulWidget` rendered above `_ConcurrencySection` in the `ListView`, separated by a `Divider`.
- [ ] Section content:
  - Title `Text('Subprocess cache (TMPDIR)')`.
  - Subtitle showing the current path (`tmpDirManager.root.path`) and current size, formatted human-readably (e.g. `"384.2 MB"`). Helper: format with `KB` / `MB` / `GB` units, 1 decimal place.
  - Trailing row with two buttons: `OutlinedButton('Refresh')` and `FilledButton.tonal('Clear cache')`.
- [ ] On mount: `await tmpDirManager.currentSize()` and `setState` to display.
- [ ] On "Refresh": re-read size.
- [ ] On "Clear cache": show a confirmation `AlertDialog` first ("Delete all cached subprocess files? This may slow down the next benchmark run while caches are rebuilt. Do not clear the cache while a benchmark is running."), then call `await tmpDirManager.clear()` and re-read size. Show a `SnackBar` with the freed-bytes delta.
- [ ] Read the manager via `context.read<TmpDirManager>()` inside `initState`.

---

## Task 7: Tests

**Files:**
- Create: `test/runner/tmpdir_manager_test.dart`

- [ ] Test plan (each test creates its own `Directory.systemTemp.createTemp('tmpdir_mgr_')` root and uses `addTearDown` to delete it):
  - `currentSize` returns 0 for an empty dir.
  - `currentSize` returns 0 when `root` does not exist.
  - `currentSize` correctly sums a few files of known sizes (use `writeAsBytes` with `List.filled(N, 0)`).
  - `currentSize` recurses into subdirs.
  - `currentSize` does not follow symlinks.
  - `sweep` deletes top-level entries older than `maxAge` (set the mtime via `entity.setLastModifiedSync(...)` to simulate an old entry).
  - `sweep` retains entries newer than `maxAge`.
  - `sweep` with a tight `maxBytes` deletes oldest entries until under budget.
  - `sweep` does not throw when `root` does not exist (covers fresh install).
  - `clear` empties the dir but leaves `root` itself in place.
  - `clear` is a no-op on a missing root (creates it).

- [ ] Update existing tests that construct `App` or wrap `SettingsPage` so they provide a `TmpDirManager`:
  - `test/widget_test.dart`: pass `tmpDirManager: TmpDirManager(root: Directory(...))` to `App`.
  - `test/ui/pages/settings_page_custom_providers_test.dart`: add `RepositoryProvider<TmpDirManager>.value(...)` around `SettingsPage`.

- [ ] Run:

```bash
flutter test test/runner/tmpdir_manager_test.dart
```

All tests must pass.

---

## Task 8: Verification

- [ ] `flutter analyze` — zero issues.
- [ ] `flutter test` — all tests pass (no regressions in existing suite).
- [ ] Smoke test (manual, document in PR description): launch the app with `flutter run -d linux`, kick off a one-task benchmark, confirm via `ls ~/.local/share/dart_arena/tmp/` that new entries appear there (not in `/tmp`), and that the Settings → Cache section reflects a non-zero size.

---

## Non-goals

- No per-run cleanup. Snapshot caches in `TMPDIR` are reusable and dropping them between runs would penalize benchmark consistency.
- No background timer / periodic sweep beyond startup. Manual button + startup sweep is sufficient for current usage.
- No Windows-specific testing in CI. The implementation handles Windows via `SetEnvironmentVariableW` but is not validated automatically.
- No telemetry / logging of cache size over time.
