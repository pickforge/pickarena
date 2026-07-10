Fix `FeedRefreshController` so the feed refresh logic is safe when refreshes overlap.

Context: the controller loads a list of `FeedItem`s from a `FeedRepository` and exposes the
current `RefreshState` (status, items, and whether a retry is allowed). Users can pull-to-refresh
repeatedly and the screen can trigger a forced reload, so refreshes can overlap.

Requirements:
- Preserve the public API: `FeedItem`, `RefreshStatus`, `RefreshState`, `FeedRepository`, and
  `FeedRefreshController` with its `state`, `refresh()`, `forceRefresh()`, `retry()`, `canRetry`, and
  `isLoading` members.
- `isLoading` exposes whether a repository load is currently in flight (true from when a load starts
  until it settles), so the UI can show a loading spinner.
- `refresh()` must collapse duplicate calls: while a refresh is already in flight, calling
  `refresh()` again must not start another repository load.
- `forceRefresh()` must start a new repository load even if one is already in flight, and only the
  most recently started request may update the state.
- A stale result from an older request must never overwrite the state produced by a newer request.
  This applies to both stale successes and stale errors.
- `retry()` must only start a load when the controller is currently in the error state; otherwise it
  does nothing.
- `canRetry` must be true only while the controller is in the error state.
- On success the state holds the loaded items; on failure the state reflects the error and allows a
  retry.

Keep the controller deterministic: do not add timers, delays, or wall-clock logic.
