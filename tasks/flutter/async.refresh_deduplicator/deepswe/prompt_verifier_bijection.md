# Prompt/verifier bijection

## Classification

Restricted evaluator-only artifact. This file names hidden verifier cases and must not be provided to solvers.

## Status

Bijection evidence is current for the async DeepSWE slice: clean replay, solver patch scans, 10-run hidden flake loop, and three fresh solver reruns are recorded. Full DeepSWE completion remains pending on provider-internal stream chunks, broader performance sampling, clean committed provenance, and authored-by provenance.

## Sources

- `instruction.md`
- `baseline/test/feed_refresh_controller_test.dart`
- source hidden verifier: `hidden_tests/test/_hidden/feed_refresh_controller_hidden_test.dart`
- grading injection path: `test/_hidden/feed_refresh_controller_hidden_test.dart`
- `qa/admission_report.json`
- `qa/v1plus_report.md`
- `replay_manifest.json`
- `flake_report.json`
- `leakage_scan_result.json`

## Requirement to verifier mapping

| Requirement | Public coverage | Hidden coverage | Evidence status |
| --- | --- | --- | --- |
| Preserve public API: `FeedItem`, `RefreshStatus`, `RefreshState`, `FeedRepository`, `FeedRefreshController`, `state`, `refresh()`, `forceRefresh()`, `retry()`, `canRetry`, `isLoading` | Public tests compile/use controller, state, `refresh()`, `retry()`, `canRetry`, and `isLoading`. | Hidden tests compile/use `FeedRepository`, `forceRefresh()`, `refresh()`, `retry()`, state/items. | `api_breaking` negative rejected; fresh solver patches replay cleanly. |
| `isLoading` is true while a load is in flight and false after settle. | Public happy-path test asserts true during load and false after success. | Covered indirectly in hidden async flows; no separate multi-force `isLoading` stress case. | Partial but accepted; keep as a known coverage nuance. |
| `refresh()` collapses duplicate calls while already in flight. | Not public-covered. | `duplicate refresh while loading issues exactly one repository call`. | Covered; baseline fails, reference and three fresh solvers pass. |
| `forceRefresh()` starts a new load while another request is pending. | Not public-covered. | `forceRefresh starts a newer request while an older one is pending`. | Covered; baseline fails, reference and three fresh solvers pass. |
| Only the latest request may update state. | Not public-covered. | Force/stale hidden cases verify newer result wins. | Covered for stale success/error. |
| Stale older success never overwrites newer state. | Not public-covered. | `a stale older success does not overwrite a newer success`. | Covered. |
| Stale older error never overwrites newer state. | Not public-covered. | `a stale older error does not overwrite a newer success`. | Covered. |
| `retry()` only starts a load in error state. | Public error/retry test reaches success. | `retry from error issues exactly one new call and can reach success`; final hidden case checks retry no-op outside error. | Covered. |
| `canRetry` true only in error state. | Public checks false after success and true after error. | `canRetry is true only in the error state`. | Covered. |
| Success stores loaded items; failure reflects error and allows retry. | Public covers success items and error→retry success. | Hidden covers success items across dedup/force/retry and stale-error behavior. | Covered. |
| Deterministic async behavior without sleeps/timers. | Tests use controlled `Completer`s. | Hidden tests also use controlled completion. | No static sleep/timer negative yet; behavior remains deterministic in 10-run loop. |

## Hidden assertion back-mapping

| Hidden case | Instruction sentence enforced |
| --- | --- |
| `duplicate refresh while loading issues exactly one repository call` | `refresh()` must collapse duplicate calls: while a refresh is already in flight, calling `refresh()` again must not start another repository load. |
| `forceRefresh starts a newer request while an older one is pending` | `forceRefresh()` must start a new repository load even if one is already in flight, and only the most recently started request may update the state. |
| `a stale older success does not overwrite a newer success` | A stale result from an older request must never overwrite the state produced by a newer request. |
| `a stale older error does not overwrite a newer success` | A stale result from an older request must never overwrite the state produced by a newer request, including stale errors. |
| `retry from error issues exactly one new call and can reach success` | `retry()` must only start a load when the controller is currently in the error state. |
| `canRetry is true only in the error state` | `canRetry` must be true only while the controller is in the error state; `retry()` does nothing outside error. |

## Evidence pointers

- Clean replay: `replay_manifest.json`
- Three fresh solver reruns: `solver_runs/{kimi,minimax,gpt}/rerun_2026_06_19/`
- 10-run hidden flake loop: `flake_runs_10/flake_loop_10_result.json`
- Solver-facing leakage scan: `leakage_scan_result.json`

## Known coverage nuances

- Multi-force `isLoading` is not isolated as its own hidden assertion, though replayed accepted patches preserve visible loading behavior.
- No static `sleeps_or_real_timers` negative exists yet.
- Strict author/red-team/solver independence remains not fully evaluable because original authored-by provenance is not durably known.
