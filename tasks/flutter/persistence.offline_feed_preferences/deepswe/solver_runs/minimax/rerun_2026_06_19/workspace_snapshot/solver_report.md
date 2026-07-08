# solver_report.md

## Changed
- `lib/offline_feed_preferences.dart` — `OfflineFeedPreferencesRepository.save(...)` now writes every
  field through the injected `store`:
  - `sortOrderKey` ← `preferences.sortOrder.name`
  - `filterKey` ← `preferences.filter.name`
  - `downloadedOnlyKey` ← `preferences.downloadedOnly.toString()` (yields `"true"` / `"false"`)
  - Then updates the in-memory `_cached` as before.
- No other files changed. Public API, static keys, defaults, `load()`, parsing, and error fallback
  behavior are untouched.

## Why
The repository previously only updated its private cache on `save()`, so nothing was ever written to
the underlying `OfflineFeedPreferencesStore`. After an app restart the new repository saw an empty
store and `load()` returned `OfflineFeedPreferences.defaults`, losing the user's choices. Writing
the persisted strings also makes a fresh repository constructed over the same store restore the
saved values (the existing `load()` already maps `enum.name` and the literal `"true"`/`"false"`
strings back into typed values, with per-field fallback for missing or malformed entries).

## Validated
- `flutter pub get` — success.
- `flutter test test/offline_feed_preferences_test.dart` — 4 / 4 passed:
  - empty store loads default offline feed preferences
  - save then load on the same repository returns the latest preferences
  - loads valid preference strings already present in the store
  - copyWith and equality preserve value-object behavior

## Risks / uncertainties
- None identified. The change is additive to `save()` only; `load()`, the public surface, and the
  parsing helpers (including the unknown/malformed fallback paths) are unchanged, so the requirement
  that `load()` must never throw is preserved. No new dependencies, IO, or platform channels were
  introduced.