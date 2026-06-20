**Summary**

Changed `lib/feed_refresh_controller.dart` only:
1. `refresh()` returns immediately when `_inFlight` is true (dedupe overlapping calls).
2. `retry()` returns immediately unless `state.status == RefreshStatus.error`.
3. `_load()` checks `requestId != _latestRequestId` before writing success/error state, so stale results from older overlapping requests cannot overwrite newer state. `_inFlight` clearing remains guarded by the same check.

Validated: `flutter pub get` succeeded; `flutter test test/feed_refresh_controller_test.dart` reports `+2: All tests passed!`. Report written to `solver_report.md`. No git actions taken.