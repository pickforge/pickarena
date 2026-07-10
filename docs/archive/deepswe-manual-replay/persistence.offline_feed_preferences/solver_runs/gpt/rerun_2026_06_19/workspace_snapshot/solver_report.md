Changed:
- `OfflineFeedPreferencesRepository.save` now persists sort order, filter, and downloaded-only values through the injected store.
- Enum values are saved with `.name`; booleans are saved as `"true"` or `"false"`.
- `load()` now reads from the store source of truth instead of returning a stale in-memory cache.

Validated:
- `flutter test test/offline_feed_preferences_test.dart`
