# async.refresh_deduplicator — Solver Report

## Changed
- `lib/feed_refresh_controller.dart`
  - Replaced single `_inFlight` boolean with `_inFlightCount` so `isLoading` stays true while any repository load is active.
  - Made `refresh()` deduplicate: it returns immediately when a load is already in flight and does not start another repository call.
  - Made `forceRefresh()` always start a new `_load()`, and only the latest request (by `_latestRequestId`) may update `_state`.
  - Made stale successes and stale errors silently ignored by wrapping the state updates in `if (requestId == _latestRequestId)`.
  - Made `retry()` only start a load when the current status is `error`; otherwise it returns without doing anything.

## Validated
- Ran `flutter test` in the workspace.
- Both public tests passed:
  - `single refresh goes loading then success and stores items`
  - `error enables retry and retry can reach success`

## Risks/uncertainties
- Hidden tests may exercise overlapping `forceRefresh` calls or mixed `refresh`/`forceRefresh` sequences; the request-ID guard and in-flight counter should handle them, but I have not run those tests.
- `refresh()` currently returns `Future.value()` when deduplicated rather than awaiting the in-flight load. This satisfies the stated requirement of not starting another load, but a test could conceivably expect it to await the active request.

## Commands run
```
flutter test
```