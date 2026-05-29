# Phase 5 — Human Review and Preference Ranking Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`
> **Dependencies:** Best after Phase 4; can start earlier as a standalone prototype.

## Goal

Add an Arena-style blind human preference layer for subjective Flutter quality signals that automated tests cannot fully capture.

This should rank passing or near-passing solutions by merge preference, UI polish, maintainability, and idiomatic Flutter quality.

## Success criteria

- Reviewers can compare two anonymized submissions for the same task.
- Model/provider identities are hidden during voting.
- Reviewers can choose A, B, tie, or skip.
- Votes are persisted.
- A quality leaderboard can compute pairwise preference scores.
- Human preference is reported separately from primary correctness.

## Current code anchors

- `TaskRunDetailsPage` can already show output, diff, evaluations, and prompt for a single task run.
- `RunDao` exposes task-run and evaluation lookup methods, but there is no review repository/table yet.
- `LeaderboardPage` and `LeaderboardRepository` are correctness/aggregate-score oriented today.
- Drift schema changes require updating `lib/storage/database.dart`, migration tests, and regenerated `database.g.dart`.

## Scope

Human review should be secondary. It should not override hidden-verifier correctness.

Use it for:

- UI polish;
- visual/layout quality;
- architecture;
- maintainability;
- test quality;
- code review tasks;
- choosing between multiple passing solutions.

Do not use it as the primary pass/fail grader for behavioral correctness.

## Architecture

Add review data beside benchmark results:

```text
TaskRun
  final code/patch/evaluator output

ReviewBattle
  taskId
  taskVersion
  benchmarkTrack
  leftTaskRunId
  rightTaskRunId
  reviewerId/local alias
  vote
  rationale
  createdAt
```

Quality leaderboard:

```text
pairwise votes -> win rates -> Bradley-Terry/Elo-style score
```

Start simple with win-rate tables, then add Bradley-Terry once enough votes exist.

## File structure

Likely files to create:

- `lib/review/review_battle.dart`
- `lib/review/review_repository.dart`
- `lib/review/preference_ranking.dart`
- `lib/ui/pages/review_queue_page.dart`
- `lib/ui/widgets/review_comparison_view.dart`
- `test/review/preference_ranking_test.dart`
- `test/ui/pages/review_queue_page_test.dart`

Likely files to modify:

- `lib/storage/database.dart`
- `lib/app.dart`
- `lib/ui/pages/run_details_page.dart`
- `lib/ui/pages/leaderboard_page.dart`

## Task 1: Add review storage

- [ ] Add `ReviewBattles` table.
- [ ] Store:
  - task ID;
  - task version;
  - benchmark track;
  - left/right task-run IDs;
  - anonymized labels;
  - vote;
  - optional rationale;
  - created time.
- [ ] Add DAO/repository methods.
- [ ] Add migration and tests.
- [ ] Add a uniqueness guard for reviewer + unordered task-run pair so the same reviewer does not repeatedly vote on the same battle.

Vote enum:

```text
left
right
tie
skip
```

Store reviewer identity as a local alias or generated local ID only. Do not require authentication for the first local-only implementation.

## Task 2: Build battle selection

- [ ] Select pairs from the same task and compatible track.
- [ ] Prefer submissions that passed primary correctness.
- [ ] Avoid showing the same pair repeatedly.
- [ ] Randomize left/right order.
- [ ] Hide model/provider/run identity until after voting.
- [ ] Prefer pairs with the same task version and similar verifier status.
- [ ] Avoid pairing two submissions from the same provider/model unless there are no alternatives.
- [ ] Do not select task runs whose output/patch is unavailable.

## Task 3: Build review UI

- [ ] Add a review queue page.
- [ ] Show task prompt and relevant public context.
- [ ] Show two submissions side-by-side:
  - code diff or final file for codegen tasks;
  - patch for agentic tasks;
  - evaluator summary;
  - screenshots/golden artifacts later if available.
- [ ] Add voting controls: A, B, Tie, Skip.
- [ ] Add optional rationale field.
- [ ] Reveal identities only after vote submission if desired.
- [ ] Use stable anonymous labels per battle, such as `A` and `B`, not model-derived names.
- [ ] Clearly label automated correctness status without exposing model identity.
- [ ] Keep screenshots/golden artifacts out of the first pass unless Phase 3 produced stable artifacts.

## Task 4: Add preference ranking

- [ ] Compute per-model pairwise wins/losses/ties.
- [ ] Add average win rate against other models.
- [ ] Add minimum-vote thresholds.
- [ ] Later add Bradley-Terry or Elo-style ranking.
- [ ] Show confidence/low-vote warnings.
- [ ] Count `skip` for audit volume but exclude it from win-rate denominators.
- [ ] Report human preference separately by track and task version when enough data exists.

## Task 5: Add Flutter-specific review rubrics

Add rubric presets:

- [ ] UI/UX polish;
- [ ] idiomatic Flutter;
- [ ] accessibility;
- [ ] maintainability;
- [ ] architecture/state management;
- [ ] test quality;
- [ ] merge readiness.

The UI should remind reviewers:

> Pick the solution you would rather merge, assuming both are intended to solve the same task.

Rubrics should be task-type hints only; they should not change hidden-verifier pass/fail or the correctness leaderboard.

## Task 6: Integrate with leaderboard

- [ ] Add a separate `Quality` tab or filter.
- [ ] Keep correctness leaderboard primary.
- [ ] Show human preference score only when enough votes exist.
- [ ] Add model detail view with battle history and common reviewer rationales.
- [ ] Do not blend human preference into aggregate correctness scores.
- [ ] Add low-vote warnings anywhere preference rank is displayed.

## Validation

Run:

```sh
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Targeted:

```sh
flutter test test/review/
flutter test test/ui/pages/review_queue_page_test.dart
```

Manual smoke:

- create a run with at least two models on the same task;
- open review queue;
- vote on a battle;
- confirm identities are hidden before vote;
- confirm ranking updates.

## Risks

- Human votes are subjective and can be noisy.
- Small vote counts can create misleading rankings.
- Reviewers may be biased if identities leak through code style or comments.
- Side-by-side code comparison is not enough for visual UI tasks; screenshots/goldens should be added later.
- Generated code may contain model-identifying comments or style fingerprints; anonymization hides metadata but cannot fully remove style-based clues.
- Preference data can become stale when task versions change; rankings must separate or filter by task version.

## Exit criteria

Phase 5 is complete when the app can collect blind pairwise votes and show a separate human-preference quality leaderboard with clear sample-size warnings.

Rollback/compatibility:

- Review tables are additive and should not affect benchmark execution.
- If review ranking has issues, hide the Quality tab while preserving collected votes for later migration.
