# Phase 4 — Reliable Leaderboard Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`
> **Dependencies:** Phase 1 verifier integrity; useful but not strictly dependent on Phase 2/3.

## Goal

Make leaderboard rankings statistically interpretable by adding repeated trials, confidence intervals, cost/time/token reporting, rank uncertainty, and failure taxonomy.

## Success criteria

- Runs can execute multiple trials per model/task, and the New Run UI can configure the trial count.
- Leaderboard leads with measured pass rate plus confidence interval, with legacy aggregate/dimension scores clearly secondary.
- Leaderboard shows task/trial count and warns on low sample size.
- Cost, latency, and token summaries are visible.
- Failures are classified into useful categories.
- Export formats include per-trial fields and aggregate uncertainty summaries.

## Current code anchors

- Phase 4-lite already added `trialsPerTask` to `StartRunConfig` and `StartRun`; `RunBloc._onStart` expands task/provider/model/trial combos, labels trial progress, persists `trialIndex`, and `RetryCombo` deletes by run/provider/model/task/trial.
- `TaskRuns` already has `trialIndex`, `taskVersion`, `benchmarkTrack`, `harnessId`, `primaryPass`, `failureTag`, plus Phase 2 `patchText` and `trajectoryLogPath` in schema version 5. Verify and extend these columns; do not add duplicates.
- `TaskRunResult`, `RunDao`, codegen runs, and agentic runs already pass through the trial/track/primary-pass/failure fields.
- `lib/analytics/result_primitives.dart` already computes `primaryPass` and a basic deterministic `failureTag`; Phase 4-full should harden the taxonomy and tests instead of reimplementing the primitive from scratch.
- `LeaderboardRepository` exposes `primaryPassCount`, `primaryPassSampleCount`, and `primaryPassRate`, but `ModelRanking` still lacks confidence intervals, cost/time/token summaries, failure breakdowns, and a reliable default ranking comparator.
- `NewRunPage` still defaults to one trial because it has no trial-count control bound into `StartRunConfig.trialsPerTask`.
- CSV/Markdown run-summary exports already include per-trial metadata; Phase 4-full should add aggregate leaderboard summary fields and improve unknown/null formatting.

## Architecture

Current storage treats each task run as a row. Phase 4 should make repeated trials first-class without breaking existing rows.

Recommended model:

```text
Run
  TaskRun
    trialIndex
    taskVersion
    benchmarkTrack
    harnessId
    aggregateScore
    primaryPass
    failureTag
```

Already-present nullable/defaulted `TaskRuns` columns:

```text
trialIndex INTEGER NOT NULL DEFAULT 0
taskVersion INTEGER NOT NULL DEFAULT 1
benchmarkTrack TEXT NOT NULL DEFAULT 'codegen'
harnessId TEXT NULL
primaryPass BOOL NULL
failureTag TEXT NULL
```

If Phase 2 already added `benchmarkTrack` or `harnessId`, reuse those columns instead of adding duplicates.

Do not add an `estimatedCostMicros` column in the first pass. Cost should be computed on demand from persisted prompt/completion token counts and a local static pricing registry, so changed pricing can be reflected without a migration. Missing tokens or missing pricing means unknown cost, not zero.

Recommended analytics models:

```text
ConfidenceInterval
  lower
  upper
  confidenceLevel

ModelPricing
  inputCostPerMToken
  outputCostPerMToken

ModelRanking additions
  primaryPassCount
  primaryPassSampleCount
  primaryPassRate
  primaryPassInterval
  lowSample
  medianLatencyMs
  medianPromptTokens
  medianCompletionTokens
  medianEstimatedCostMicros
  costPerSolvedTaskMicros
  failureBreakdown
```

`LeaderboardRepository` should compute these fields once while building ranking/detail models. Widgets should read the prepared fields instead of recomputing statistics in `build`.

Analytics aggregate by:

- model;
- provider/harness;
- task;
- category/tag;
- track;
- trial count.

## File structure

Likely files to create or extend:

- `lib/analytics/confidence_interval.dart`
- `lib/analytics/benchmark_statistics.dart`
- `lib/analytics/result_primitives.dart` or `lib/analytics/failure_taxonomy.dart`
- `lib/analytics/cost_estimator.dart`
- `test/analytics/confidence_interval_test.dart`
- `test/analytics/benchmark_statistics_test.dart`
- `test/analytics/result_primitives_test.dart` or `test/analytics/failure_taxonomy_test.dart`

Likely files to modify:

- `lib/analytics/leaderboard_repository.dart`
- `lib/analytics/dimensions.dart`
- `lib/ui/pages/leaderboard_page.dart`
- `lib/ui/widgets/ranked_models_list.dart`
- `lib/export/csv_exporter.dart`
- `lib/export/md_exporter.dart`
- `lib/ui/pages/new_run_page.dart`
- `lib/analytics/leaderboard_filter.dart` only if adding harness filtering

Storage files should only be touched for verification or tests unless the implementation uncovers a real missing field. Do not add a cost column.

## Task 1: Complete trial configuration UI

- [x] `trialsPerTask` already exists on `StartRunConfig` and `StartRun`.
- [x] `RunBloc` already expands the run matrix by trial index, labels trial runs, persists `trialIndex`, and retries/deletes by trial.
- [ ] Add a `Trials per task` control to `NewRunPage` using a small numeric input, dropdown, or segmented control.
- [ ] Bind the control into `StartRunConfig.trialsPerTask`.
- [ ] Show the pre-run count as `(provider, model) pairs × tasks × trials = task-runs`; keep default `1`.
- [ ] Clamp invalid values to at least `1` at the UI/config boundary.
- [ ] Add widget tests that the displayed count includes trials and the captured `StartRunConfig.trialsPerTask` matches the selected value.
- [ ] Keep existing runner matrix/retry behavior intact; only adjust it if validation proves a regression.

## Task 2: Verify persisted trial and track metadata

- [x] `TaskRuns` already has nullable/defaulted fields:
  - `trialIndex`;
  - `taskVersion`;
  - `benchmarkTrack`;
  - `harnessId`;
  - `primaryPass`;
  - `failureTag`.
- [x] Existing rows have safe defaults and `schemaVersion` is already past the migration that added these fields.
- [x] `TaskRunResult` and `RunDao.persistTaskRun` already pass these fields explicitly.
- [ ] Verify `database.g.dart`, migration tests, DAO tests, codegen runs, and agentic runs still cover these fields after Phase 4-full changes.
- [ ] Do not add `estimatedCostMicros`; cost is computed from existing token columns and static pricing.

## Task 3: Harden primary pass/fail primitives

- [x] `determineResultPrimitives` already maps evaluator outputs to `primaryPass` and `failureTag`.
- [x] Runner paths already store the primary pass decision for fast leaderboard queries.
- [ ] Extend tests around precedence and legacy fallback instead of replacing the primitive.
- [ ] Ensure missing token/cost/LLM judge data is never treated as a correctness failure.

Suggested primary-pass precedence:

1. hard harness errors/timeouts fail the task run;
2. when `hidden_test` / hidden verifier evaluators are present, all must pass;
3. otherwise all required public correctness evaluators pass (`compile`, `analyze`, `test`, widget tests, or task-specific test-author evaluators);
4. legacy fallback: `aggregateScore >= configured pass threshold`.

Never treat missing token/cost/LLM judge data as correctness failure.

## Task 4: Add confidence intervals

- [ ] Implement Wilson 95% interval for pass rates in `lib/analytics/confidence_interval.dart`.
- [ ] Use `z = 1.95996`.
- [ ] Return `null`/unknown for `n = 0`, not `0%`.
- [ ] Treat `n < 5` as low sample size and expose a warning flag/string.
- [ ] Add `ConfidenceInterval? primaryPassInterval` and `bool lowSample` to `ModelRanking` or a nested stats object.
- [ ] Compute intervals in `LeaderboardRepository` with the rest of the ranking data, not inside widgets.
- [ ] Show `low–high` or `pass rate (low–high)` in the leaderboard and detail pane.
- [ ] Add bootstrap helpers for medians only if a UI/export actually needs median uncertainty in this phase.

Suggested first pass:

```text
pass_rate = passes / primary_pass_sample_count
ci = Wilson 95% over primaryPassCount/primaryPassSampleCount
low_sample = primaryPassSampleCount < 5
```

Test edge cases:

- `0/0` should display unknown, not `0%`;
- `0/n` and `n/n` should still have non-zero interval width;
- one trial should always show a low-sample warning.

## Task 5: Add cost/time/token summaries

- [ ] Add `lib/analytics/cost_estimator.dart` with a local/static pricing registry.
- [ ] Use `ModelPricing(inputCostPerMToken, outputCostPerMToken)` values in USD per 1M tokens.
- [ ] Match pricing by exact `providerId:modelId` first, then provider/model fallback only if unambiguous.
- [ ] Estimate cost from prompt/completion tokens when both token data and pricing are available.
- [ ] Report:
  - median latency;
  - median input tokens;
  - median output tokens;
  - median estimated cost;
  - cost per solved task.
- [ ] Add the median/cost fields to `ModelRanking` or the same stats wrapper used for confidence intervals.
- [ ] Treat missing pricing/token data as unknown, not zero, and display/export unknowns as empty cells or `unknown`.
- [ ] Keep pricing configuration local/static for the first pass; do not fetch pricing at runtime.
- [ ] Store enough raw token data to recompute cost if pricing changes later.
- [ ] Do not add a database column for estimated cost in this phase.

## Task 6: Add failure taxonomy

Initial supported tags:

```text
pass
hidden_verifier_failed
public_tests_failed
analysis_failed
compile_failed
harness_timeout
harness_error
no_patch
invalid_output
environment_error
unknown
```

- [ ] Keep deterministic taxonomy from evaluator/harness outputs.
- [ ] Store only one primary `failureTag` per task run, using this stable precedence order:

| Order | Tag | Deterministic signal |
|---:|---|---|
| 1 | `pass` | `primaryPass == true` |
| 2 | `harness_timeout` | harness/combo failure details or rationale contain timeout |
| 3 | `environment_error` | explicit infrastructure/environment evaluator code, if available |
| 4 | `harness_error` | harness/combo/prepare failure not attributable to solution evaluators |
| 5 | `hidden_verifier_failed` | hidden verifier evaluator exists and failed |
| 6 | `compile_failed` | `compile` evaluator failed |
| 7 | `analysis_failed` | `analyze` evaluator failed |
| 8 | `public_tests_failed` | `test`, `test_author`, or `widget_tree` evaluator failed |
| 9 | `invalid_output` | empty or malformed raw model output |
| 10 | `no_patch` | non-empty response but no extractable code/patch |
| 11 | `unknown` | failure does not match a supported deterministic signal |

- [ ] Treat `regression_failed`, `missed_requirement`, `flaky_verifier`, and `suspected_cheating` as future tags unless this phase adds explicit deterministic evaluator IDs/signals for them.
- [ ] Optionally allow LLM-assisted post-run classification later, but do not make it authoritative in Phase 4.
- [ ] Show failure breakdown in model detail view.
- [ ] Keep raw evaluator details available for deeper debugging.

## Task 7: Update leaderboard UI

- [ ] Add columns for pass rate, CI, trials, median cost, median duration.
- [ ] Default reliable ranking order:
  1. rows with measured `primaryPass` samples before rows with unknown pass/fail data;
  2. Wilson lower bound descending;
  3. pass rate descending;
  4. sample count descending;
  5. median estimated cost ascending when known;
  6. median duration ascending;
  7. stable provider/model key.
- [ ] Keep the dimension radar and `ScoreDimension` sort as a clearly labeled legacy/secondary view.
- [ ] If the user explicitly selects a legacy dimension sort, still keep unknown primary-pass rows visually marked as legacy/unknown.
- [ ] Reuse existing track, category, difficulty, tag, provider, and date filters.
- [ ] Add a harness filter if agentic rows need provider/harness disambiguation.
- [ ] Add a low-sample warning when comparing models with insufficient trials.
- [ ] Show per-task variance in model detail.
- [ ] Clearly label aggregate score as legacy/secondary when pass-rate data exists.
- [ ] Avoid ranking rows with unknown `primaryPass` above rows with measured pass/fail data.

## Task 8: Update exports

- [x] Per-run CSV/Markdown exports already include trial index, primary pass, failure tag, track, and task version.
- [ ] Keep those per-trial fields intact.
- [ ] Add aggregate leaderboard summary export fields:
  - `provider_id`;
  - `model_id`;
  - `task_run_count`;
  - `primary_pass_count`;
  - `primary_pass_sample_count`;
  - `primary_pass_rate`;
  - `wilson_low`;
  - `wilson_high`;
  - `low_sample`;
  - `median_latency_ms`;
  - `median_prompt_tokens`;
  - `median_completion_tokens`;
  - `median_estimated_cost`;
  - `cost_per_solved_task`;
  - failure breakdown counts.
- [ ] Markdown includes a leaderboard summary table with uncertainty and low-sample warnings.
- [ ] Preserve compatibility with old run summaries and legacy rows where `primaryPass` is null.
- [ ] Include unknown values as empty cells or `unknown`, not `0`.
- [ ] Add export tests for legacy rows, null pricing/tokens, null CI, and fallback strings.

## Validation

Run:

```sh
flutter analyze
flutter test
```

Only run `flutter pub run build_runner build --delete-conflicting-outputs` if a Drift/codegen-backed file changes.

Targeted:

```sh
flutter test test/analytics/
flutter test test/storage/
flutter test test/runner/run_bloc_test.dart
flutter test test/ui/pages/leaderboard_page_test.dart
flutter test test/ui/pages/new_run_page_test.dart
flutter test test/export/
```

## Risks

- Repeated trials increase cost quickly; UI must show task-run counts clearly.
- Confidence intervals can be misleading if tasks are not independent.
- Cost estimates depend on accurate provider token reporting.
- Failure taxonomy will start approximate and improve with trajectory data.
- If a future storage change becomes necessary, migration mistakes can make historical run summaries unreadable; add migration tests before changing leaderboard queries.
- Regressing the existing retry-by-trial key can duplicate or delete rows for sibling trials.

## Exit criteria

Phase 4 is complete when repeated trials produce a leaderboard with pass-rate confidence intervals, cost/time/token summaries, and useful failure breakdowns.

Rollback/compatibility:

- Defaults make old task-run rows appear as `trialIndex=0`, `taskVersion=1`, `benchmarkTrack=codegen`, and unknown primary pass/failure tag until backfilled.
- If the new leaderboard has issues, keep the old aggregate ranking available as a secondary or fallback view.
