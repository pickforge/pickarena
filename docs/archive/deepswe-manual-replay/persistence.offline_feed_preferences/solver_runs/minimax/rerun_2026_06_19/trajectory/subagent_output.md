## Summary

**Root cause**: `OfflineFeedPreferencesRepository.save()` was a no-op against the injected store — it only updated a private `_cached` field, so on next launch the new repository would see an empty store and `load()` would return `OfflineFeedPreferences.defaults`.

**Fix** (1 file, `lib/offline_feed_preferences.dart`): `save(preferences)` now writes each field through the store before caching:
- `sortOrderKey` ← `preferences.sortOrder.name`
- `filterKey` ← `preferences.filter.name`
- `downloadedOnlyKey` ← `preferences.downloadedOnly.toString()` → `"true"` / `"false"`

**Public API preserved**: enums, `OfflineFeedPreferences` (incl. `copyWith`/equality/`defaults`), `OfflineFeedPreferencesStore`, `OfflineFeedPreferencesRepository.store`, and the three `static const` keys are all unchanged. `load()`, the `_parseEnum`/`_parseBool` helpers, and the per-field fallback for missing/unknown values are untouched — so unknown or malformed stored values still default only that one field without throwing.

**Validated**:
- `flutter pub get` — ok
- `flutter test test/offline_feed_preferences_test.dart` — 4/4 passed

**Report**: written to `solver_report.md`.