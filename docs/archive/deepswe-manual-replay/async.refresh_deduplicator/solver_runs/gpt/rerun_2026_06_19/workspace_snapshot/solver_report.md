Changed:
- `refresh()` now deduplicates while any load is in flight.
- `forceRefresh()` always starts a new load, and only the latest request updates state.
- Stale successes/errors are ignored, `retry()` only runs from error state, and `isLoading` tracks all active repository loads.

Commands run:
- `flutter test test/feed_refresh_controller_test.dart`
