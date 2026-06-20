Done.

**Changed:** `lib/feed_refresh_controller.dart`
- `refresh()` now collapses duplicate in-flight calls by returning the pending load future.
- `forceRefresh()` always starts a new load; stale successes/errors are ignored via request-ID guard.
- `retry()` only starts a load from the `error` state.
- `isLoading` now tracks an in-flight request count so it stays true until all overlapping loads settle.

**Validated:** `flutter pub get && flutter test` → `All tests passed!`

**Report:** `solver_report.md` written.