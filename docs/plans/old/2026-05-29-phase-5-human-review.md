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
  canonicalPairKey
  reviewerId
  reviewerAlias
  vote
  rationale
  createdAt
```

Quality leaderboard:

```text
filtered non-skip pairwise votes -> win rates -> Bradley-Terry/Elo-style score
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
- `test/review/review_repository_test.dart`
- `test/ui/pages/review_queue_page_test.dart`
- `test/ui/widgets/review_comparison_view_test.dart`

Likely files to modify:

- `lib/storage/database.dart`
- `lib/storage/database.g.dart`
- `lib/storage/settings.dart`
- `lib/app.dart`
- `lib/ui/pages/run_details_page.dart`
- `lib/ui/pages/leaderboard_page.dart`
- `test/storage/database_migration_test.dart`
- `test/ui/pages/dashboard_page_test.dart`
- `test/ui/pages/leaderboard_page_test.dart`

## Task 1: Add review storage

- [ ] Add `ReviewBattles` table to `@DriftDatabase(tables: [...])`.
- [ ] Bump Drift `schemaVersion` from 5 to 6.
- [ ] Add migration:
  - `if (from < 6) await m.createTable(reviewBattles);`
  - update migration tests for schema version 6 and additive table creation.
- [ ] Regenerate `lib/storage/database.g.dart` with build runner.
- [ ] Store:
  - battle ID;
  - task ID;
  - task version;
  - benchmark track;
  - left/right task-run IDs;
  - canonical unordered pair key;
  - anonymized left/right labels;
  - stable local reviewer ID;
  - optional reviewer alias snapshot;
  - vote;
  - optional rationale;
  - created time.
- [ ] Compute `canonicalPairKey` from the two task-run IDs in lexicographic order, for example `minId|maxId`; keep randomized left/right display assignment separate from this key.
- [ ] Enforce duplicate prevention at the database layer with a unique key or unique index on `(reviewerId, canonicalPairKey)`.
- [ ] Add foreign-key references from left/right task-run IDs to `TaskRuns`.
- [ ] Add DAO/repository methods.
- [ ] Add migration and tests.
- [ ] Add storage tests for inserting battles, reading battles, and rejecting a duplicate reviewer + unordered pair even when left/right IDs are swapped.
- [ ] Extend `SettingsRepository` with a stable local reviewer ID lifecycle:
  - `getOrCreateReviewReviewerId()` returns a generated opaque local UUID-like ID and persists it;
  - reviewer alias is editable and optional;
  - uniqueness uses the stable ID, not the alias.

Vote enum:

```text
left
right
tie
skip
```

Store reviewer identity as a local alias or generated local ID only. Do not require authentication for the first local-only implementation.

## Task 2: Build battle selection

- [ ] Select pairs with the same `taskId`, `taskVersion`, and `benchmarkTrack`.
- [ ] Prefer submissions that passed primary correctness:
  - first try pairs where both `primaryPass == true`;
  - then pairs where both are in the same non-passing/unknown bucket;
  - only mix pass buckets if no same-bucket pair is available.
- [ ] Avoid showing the same pair repeatedly.
- [ ] Randomize left/right order.
- [ ] Hide model/provider/run identity until after voting.
- [ ] Avoid pairing two submissions from the same provider/model unless there are no cross-model alternatives.
- [ ] Do not select task runs whose review artifact is unavailable:
  - codegen track requires usable generated output/diff input;
  - agentic track requires `patchText != null`;
  - evaluation summaries may be shown only after removing model/run identifiers.
- [ ] Exclude already-reviewed pairs by checking the current reviewer ID plus `canonicalPairKey`.
- [ ] Avoid unbounded O(n²) scans across all historical task runs:
  - query a bounded candidate set for one task/version/track and preferred pass bucket;
  - build candidate pairs in Dart from that bounded set;
  - filter out reviewed pair keys before random selection;
  - use fallback buckets only when the preferred bucket has fewer than two eligible candidates.
- [ ] If fewer than two eligible submissions exist, show a cold-start placeholder explaining that more runs are needed.

## Task 3: Build review UI

- [ ] Add a review queue page.
- [ ] Add `/review` route wiring in `lib/app.dart`.
- [ ] Add a dashboard/app-bar navigation entry for Review.
- [ ] Register a `ReviewRepository` provider in `App`.
- [ ] Show task prompt and relevant public context.
- [ ] Show two submissions side-by-side:
  - code diff or final file for codegen tasks;
  - patch for agentic tasks;
  - evaluator summary;
  - screenshots/golden artifacts later if available.
- [ ] First pass rendering should use scrollable code/patch blocks with existing widgets such as `SelectableText`/`DiffView`; defer adding a true side-by-side diff package.
- [ ] Add voting controls: A, B, Tie, Skip.
- [ ] Add optional rationale field.
- [ ] Reveal identities only after vote submission if desired.
- [ ] Use stable anonymous labels per battle, such as `A` and `B`, not model-derived names.
- [ ] Clearly label automated correctness status without exposing model identity.
- [ ] Keep screenshots/golden artifacts out of the first pass unless Phase 3 produced stable artifacts.
- [ ] Do not reuse `TaskRunDetailsPage` directly for pre-vote review, because it renders provider/model/run metadata.
- [ ] Build a review-only comparison bundle/view that never exposes provider ID, model ID, task-run ID, run ID, harness ID, trajectory path, or raw log names before the vote is submitted.
- [ ] Add widget tests asserting that model/provider/run identifiers are absent before voting and only appear in the optional post-vote reveal state.
- [ ] Add route/provider widget tests for opening `/review` from the app shell.

## Task 4: Add preference ranking

- [ ] Compute per-model pairwise wins/losses/ties from `ReviewBattle` rows joined to their left/right `TaskRun` rows.
- [ ] Group quality rankings by `benchmarkTrack`, `taskVersion`, and `providerId:modelId`; keep task-level filtering available for drill-downs.
- [ ] Exclude battles where both sides have the same `providerId:modelId` from preference score denominators.
- [ ] Count votes:
  - `left`/`right` as one win and one loss;
  - `tie` as 0.5 win for each side;
  - `skip` for audit volume only, not score denominators.
- [ ] Compute MVP win rate as `(wins + 0.5 * ties) / (wins + losses + ties)`.
- [ ] Add a minimum non-skip vote threshold before displaying a quality rank; start with a small local default such as 3 non-skip votes per displayed model and show low-sample warnings below it.
- [ ] Later add Bradley-Terry or Elo-style ranking.
- [ ] Show confidence/low-vote warnings.
- [ ] Report human preference separately by track and task version when enough data exists.
- [ ] Follow the existing `LeaderboardRepository` pattern for filters and sorting, but compute the initial preference rankings in Dart from filtered review rows rather than adding a cache table.
- [ ] Keep Bradley-Terry/Elo and cached ranking tables as later follow-ups, not MVP requirements.

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
- [ ] Add leaderboard tests proving the correctness ranking remains the default/primary view and quality scores are displayed only in the separate Quality view.

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
flutter test test/ui/widgets/review_comparison_view_test.dart
flutter test test/storage/database_migration_test.dart
flutter test test/ui/pages/leaderboard_page_test.dart
```

Manual smoke:

- create a run with at least two models on the same task;
- open review queue;
- vote on a battle;
- confirm identities are hidden before vote;
- confirm ranking updates.
- open the app from a cold start with fewer than two eligible submissions and confirm the review placeholder is shown.

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
