# Solver Report: persistence.offline_feed_preferences

## Changed
Fixed `OfflineFeedPreferencesRepository.save()` so it persists all preference fields through the injected `OfflineFeedPreferencesStore`:
- `sortOrder` is written as `preferences.sortOrder.name`
- `filter` is written as `preferences.filter.name`
- `downloadedOnly` is written as `"true"` or `"false"`
- In-memory cache is still updated as before

This makes a fresh repository constructed over the same store able to `load()` the previously saved values.

## Validation
Ran `flutter pub get` and public tests:

```
flutter test test/offline_feed_preferences_test.dart
```

Result: 4/4 tests passed.

## Risks/uncertainties
None. The change only fills in the missing store writes; no API surface, data model, or dependency changes.
