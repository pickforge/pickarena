Done.

Changed `lib/offline_feed_preferences.dart`: `OfflineFeedPreferencesRepository.save()` now writes all three preference fields to the injected store as `.name` for enums and `"true"`/`"false"` for the boolean, while still updating the in-memory cache.

Validated with:
- `flutter pub get`
- `flutter test test/offline_feed_preferences_test.dart` — 4/4 passed

Report written to `solver_report.md`.