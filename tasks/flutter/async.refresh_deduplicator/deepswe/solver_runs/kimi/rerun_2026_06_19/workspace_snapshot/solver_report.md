# Solver Report: async.refresh_deduplicator

## Changed behavior in `lib/feed_refresh_controller.dart`

- **Deduplicated `refresh()`**: now returns the in-flight load future and skips starting a new repository load when one is already running.
- **Corrected `forceRefresh()`**: always starts a fresh repository load; stale results from earlier requests are ignored.
- **Guarded state updates**: only the most recently started request may transition state to `success` or `error`; both stale successes and stale errors are dropped.
- **Fixed `retry()`**: only starts a load when the controller is in the `error` state; otherwise it returns a completed future.
- **Fixed `isLoading` / in-flight tracking**: replaced a single boolean with a request-count integer so `isLoading` stays `true` while any repository load is in flight and becomes `false` only after the last in-flight request settles.
- Preserved the public API and kept the logic deterministic (no timers, delays, or wall-clock checks).

## Commands run

```sh
flutter pub get
flutter test
```

Result: `00:00 +2: All tests passed!`
