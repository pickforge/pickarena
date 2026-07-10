1. Changed
- Persisted all offline feed preference fields via `OfflineFeedPreferencesStore`.
- Saved enums using `.name` and booleans as `"true"` / `"false"`.
- `load()` now reads from the store instead of stale memory cache.
- Wrote `solver_report.md`.

2. Validated
- `flutter test test/offline_feed_preferences_test.dart`

3. Risks/uncertainties
- None.