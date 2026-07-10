# solver_report

## Changed behavior in `lib/feed_refresh_controller.dart`

- `refresh()` now bails out (returns immediately) when a load is already in flight, so duplicate
  calls never start another repository load.
- `retry()` now only triggers a load when the current status is `RefreshStatus.error`; otherwise it
  is a no-op.
- `_load()` guards every state write (success and error) with a `requestId == _latestRequestId`
  check, so a stale result from an older overlapping request can never overwrite state produced by
  a newer request. `_inFlight` is still only cleared by the most recent request in the `finally`.

Public API, status transitions, and `canRetry` / `isLoading` semantics are unchanged.

## Commands run

- `flutter pub get` — resolved deps for `async_refresh_deduplicator`.
- `flutter test test/feed_refresh_controller_test.dart` — `+2: All tests passed!` (both public tests).