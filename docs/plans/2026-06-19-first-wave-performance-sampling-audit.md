# First-wave performance sampling audit

Status: active audit
Created: 2026-06-19

This is artifact-scope duration/performance sampling from existing DeepSWE artifacts only, not a statistical benchmark and not DeepSWE completion.

JSON: [`2026-06-19-first-wave-performance-sampling-audit.json`](./2026-06-19-first-wave-performance-sampling-audit.json)

## Summary

| Task | Slice state | Solver samples | Public replay | Hidden replay | Command samples | QA repetition | 10-run loop | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `async.refresh_deduplicator` | accepted-artifact-scope-slice | 3 fresh/final + 2 legacy | 3/3 solver reruns; 3 commands | 3/3 solver reruns; 3 commands | 7 total; 0 failures | 5/5 pass; duration unavailable | 5 targets / 50 runs; 0 expectation failures | accepted artifact-scope slice; 3 fresh solver samples plus 2 legacy initial solver metadata samples |
| `accessibility.quantity_stepper_semantics` | accepted-artifact-scope-slice | 5 | 5/5 solver reruns; 5 commands | 3/5 solver reruns; 5 commands | 10 total; 2 failures | 5/5 pass; 5 timed | 7 targets / 70 runs; 0 expectation failures | accepted artifact-scope slice; two hidden failed reruns retained as failed solver evidence |
| `refactor.price_label_formatter` | accepted-artifact-scope-slice | 4 | 4/4 solver reruns; 4 commands | 3/4 solver reruns; 4 commands | 8 total; 1 failure | 5/5 pass; duration unavailable | 6 targets / 60 runs; 0 expectation failures | accepted artifact-scope slice; one hidden failed rerun retained as failed solver evidence |
| `persistence.offline_feed_preferences` | accepted-artifact-scope-slice | 4 | 4/4 solver reruns; 4 commands | 4/4 solver reruns; 4 commands | 8 total; 0 failures | 5/5 pass; 5 timed | 6 targets / 60 runs; 0 expectation failures | accepted artifact-scope slice; all fresh reruns public+hidden passed |
| `ui.action_bar_overflow` | accepted-artifact-scope-slice | 4 fresh/final + 1 aborted metadata-only | 4/4 solver reruns; 4 commands | 3/4 solver reruns; 4 commands | 8 total; 1 failure | 5/5 pass; 5 timed | 6 targets / 60 runs; 0 expectation failures | accepted repair evidence; gpt, minimax, and kimi promoted; GLM failed; opus aborted/unavailable |

## Overall aggregates

- Tasks audited: 5; accepted artifact-scope slices: 5; failed candidate slices: none.
- Solver metadata samples: 23 total = 20 comparable fresh/final + 2 async legacy initial + 1 action-bar aborted Opus metadata-only sample.
- Solver reruns: public passed 20/20; hidden passed 16 and failed 4.
- Command records: 41 total = 20 public replay + 20 hidden replay + 1 measured full QA; 4 failures, all expected hidden failures from failed solver evidence.
- Full QA repetition: 25 runs, 0 failures; QA duration samples available for 15 runs and unavailable for 10 runs.
- Hidden 10-run loops: 30 targets, 300 runs, 0 expectation failures; run-duration samples available for 250 runs and unavailable for 50 runs.
- Solver duration sampling: n=23, median=128039ms, p95=652764ms; comparable fresh/final n=20, median=125571.5ms, p95=277498ms.

## Redaction and limitations

- Hidden command strings, restricted log contents, restricted hidden log filenames, hidden test paths, prompt-verifier/f2p contents, and session JSONL contents are not copied.
- Included fields are limited to task IDs, family/model names, durations, token/cost metadata where available, pass/fail counts, exit-code counts, booleans, and source artifact JSON paths.
- This audit uses existing artifacts only; it is artifact-scope performance sampling, not a statistical benchmark.
- Full QA measured duration is limited to the async `full_task_qa_hidden_flake_5` command; QA repetition run durations are summarized separately where present.
- Flake loop durations use per-run and target pub-get durations where present; async flake loop artifacts provide pass/fail counts without per-run durations, and active action-bar target pub-get durations are unavailable.
- The pre-contract-repair `ui.action_bar_overflow` failed candidate is archived and excluded from active counts and telemetry.

## Remaining blockers

- provider-internal stream/session JSONL gaps
- clean committed provenance / gitDirty=false
- durable authored-by provenance
- runtime workspace isolation remains artifact-scope only
- performance sampling remains artifact-scope and is not a statistical benchmark
