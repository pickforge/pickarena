# Plan 8 — Planning + Execution Benchmark (Design)

> **Status:** Draft design. Awaiting user review before implementation-plan authoring (`writing-plans`).
> **Source roadmap stub:** `docs/roadmap/2026-05-03-plan-8-planning-and-execution.md`
> **Depends on:** Plan 7 (DI refactor; `StartRunConfig`).

## 1. Goal

Measure each model's **planning** and **execution** as separable graded skills, in addition to today's single-shot code score. The benchmark currently conflates the two; a strong planner / weak executor and a weak planner / strong executor are indistinguishable in the leaderboard.

The plan is delivered in three phases of **decreasing depth-of-commitment** within a single design doc:

- **Phase B — implementation-ready.** Reference-plan execution: a curated human plan is injected into the executor prompt; the model only executes. Cleanly isolates executor skill. Ships first.
- **Phase A — design-level.** Self-plan execution: the model produces a plan, then executes against it. Pins the load-bearing decisions (storage shape, score combination, plan format, judge-validation gate) in this spec; per-task rubrics and orchestration code are deferred to a follow-up mini-spec.
- **Phase C — directional sketch.** Cross-model planner × executor pairings. Schema must support it; UI is sketched only.

Phase B → A → C ordering is **deliberate and reverses the roadmap stub**. Reference plans are scientifically cleaner (executor isolated, no plan/execute covariance) and produce reference data that Phase A can validate its plan judge against.

## 2. Scope

### 2.1 In scope (Phase B — implementation-ready)

- New `Category.planningAndExecution`.
- New `MultiFileBenchmarkTask` mixin or extension of `BenchmarkTask` so a task can declare multi-file output and a `referencePlan` field. Single-file tasks remain unchanged.
- **Three new tasks** under `lib/tasks/planning_and_execution/`, each with a frozen fixture tree under `assets/fixtures/planning_and_execution/<task_id>/` and a frozen reference plan checked into source.
  - Initial set: `add_evaluator_type` and `add_filter_dimension` (full implementation), plus `refactor_run_bloc_cancellation` (stub task; reference plan only) so the schema and UX are exercised by ≥ 2 working tasks at landing.
- New schema: `Plans` table with `(id, taskId, plannerModelId NULLABLE, referenceVersion NULLABLE, artifact, createdAt)`; new nullable `planId` FK on `TaskRuns`. Migration `schemaVersion: 3`.
- New value-object field `StartRunConfig.useReferencePlan: bool` (default `false`).
- `RunBloc` consumes the reference plan when `useReferencePlan = true` and a task carries one; injects it into the prompt via a slot in the prompt template.
- `NewRunPage` "Use reference plan" toggle (a `SwitchListTile` near the existing model/provider selectors). Disabled (greyed out) unless the selected task set includes at least one task that *has* a reference plan.
- `RunBloc` persists `planId` on each `TaskRunResult` for runs that used a plan; null otherwise. Reference-plan rows are inserted into `Plans` once at task-load time (idempotent on `(taskId, referenceVersion)`).
- Geometric-mean stage-combination function, scaffolded but **inert in Phase B** (only one stage exists, so combine is a no-op). The combine module ships now so Phase A doesn't have to migrate scoring later.
- Tests:
  - `test/runner/run_bloc_plan_aware_test.dart` — when `useReferencePlan = true`, assert the executor receives the plan in its prompt; when `false`, assert prompt is unchanged from today.
  - `test/storage/plans_dao_test.dart` — round-trip a reference plan, verify FK from `TaskRuns.planId`.
  - `test/tasks/planning_and_execution/<task>_test.dart` — fixture-load smoke test per new task.
  - `test/ui/pages/new_run_page_test.dart` — extend: toggle is disabled when no reference-plan tasks selected; toggle propagates into `StartRunConfig`.

### 2.2 In scope (Phase A — design-level only)

Pinned in this spec; implementation deferred to a Phase A mini-spec.

- Stage shape: a two-stage `MultiStageBenchmarkTask` (plan stage → execute stage). Plan stage produces a markdown artifact with a fenced `` ```plan `` block convention (extracted by a tolerant parser).
- New evaluators: `plan_judge` (LLM-against-rubric, modeled on existing `llm_judge`) and `plan_structure` (cheap heuristics).
- **Stage combination function:** geometric mean of clamped stage scores. Pinned now; B will instantiate the no-op identity case.
- **Plan-judge validation gate:** before Phase A enables `plan_judge` in default weights, a fixture-based judge-variance harness must demonstrate (a) intra-fixture variance < threshold, (b) ordering of canonical good/medium/bad fixtures stable under K=10 re-rolls. If fail → fall back to `plan_structure` + execute-stage success only. This is a hard gate, not a soft preference.
- Storage already supports per-run plan artifacts (Phase B's `Plans` table covers this with `plannerModelId` set).

### 2.3 In scope (Phase C — directional sketch)

Sketched; not specced.

- `NewRunPage` exposes separate planner-model and executor-model selectors behind an "Advanced: cross-model planning" expansion tile.
- New leaderboard view: pairing-matrix heatmap (planner axis × executor axis, score in cells) reusing Plan 6 dimension/filter infra.
- Cost-preview chip showing task-run count *before* the Run button enables.
- Phase C reuses the `Plans` table verbatim; one plan per `(planner, task)` pair, fanned out across executors. No new schema work.

### 2.4 Out of scope (explicit deferrals)

- Modifying or migrating any existing single-shot tasks (Plans 1–5 stay as-is).
- Multi-turn execution within a stage. Executor is still one-shot per task.
- Real agentic loops ("retry until tests pass").
- Brainstorm-as-its-own-stage. The cascade has four canonical stages; this plan compresses to two for tractability.
- Live-progress UI for stages. The existing single progress bar is reused.
- Cost *prediction* (only count preview).
- Migrating analytics (`Dimensions`) to be plan-aware. Plan 8 leaderboard view is a separate page; existing leaderboard ignores plan-related task-runs by filtering on `Category.planningAndExecution`.

## 3. Architecture

### 3.1 Task-shape extension

The current `BenchmarkTask` returns a single `generatedCodePath` and a single-file `fixtures` map. Plan-and-execute tasks frequently span multiple files. Two options considered:

- **Option I — break the existing interface** (`generatedCodePath: String → List<String>`, single response → multi-file response).
- **Option II — additive: introduce `MultiFileBenchmarkTask` that extends `BenchmarkTask`,** keeping single-file tasks untouched. New extractor for multi-file responses. Single-file callers ignore the new fields.

**Decision: Option II.** Plans 1–5 remain bit-identical; new tasks opt in. This avoids regressing any of the ~10 existing tasks for a feature that only 3 new tasks need.

```dart
// lib/core/benchmark_task.dart  (extension; existing interface untouched)
abstract class MultiFileBenchmarkTask extends BenchmarkTask {
  /// Output paths the executor is expected to write under workdir.
  /// Replaces single-file [generatedCodePath] for multi-file tasks; the
  /// inherited single-file getter returns the first entry for backwards
  /// compat with code_extractor / workdir_manager.
  List<String> get generatedCodePaths;

  @override
  String get generatedCodePath => generatedCodePaths.first;

  /// Frozen, in-repo plan. `null` means task has no reference plan
  /// and is therefore unavailable for [StartRunConfig.useReferencePlan].
  ReferencePlan? get referencePlan;
}

class ReferencePlan {
  const ReferencePlan({
    required this.version,
    required this.markdown,
  });

  final int version;        // bumping invalidates historical plan-aware runs
  final String markdown;    // ~200-400 words; loaded from assets/
}
```

`code_extractor.dart` gains a sibling extractor `extractDartFiles` that parses fenced blocks of the form `` ```dart filename: lib/foo.dart `` and returns `Map<String, String>`. The single-file extractor stays as-is; new tasks call the multi-file one.

`WorkdirManager.createTaskWorkdir` already accepts a `fixtures` map and one `generatedCode` string. For multi-file: if `generatedCodePaths.length > 1`, call `createTaskWorkdir` with `fixtures` augmented by the parsed file map and `generatedCode = null`. Adds one helper to the manager; no shape change.

### 3.2 `Plans` table and migration

```dart
// lib/storage/database.dart
class Plans extends Table {
  TextColumn get id => text()();                              // uuid
  TextColumn get taskId => text()();
  TextColumn get plannerModelId => text().nullable()();       // null = reference plan
  IntColumn get referenceVersion => integer().nullable()();   // set iff reference
  TextColumn get artifact => text()();                        // markdown
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class TaskRuns extends Table {
  // ... existing columns ...
  TextColumn get planId => text().nullable().references(Plans, #id)();
}
```

Migration (`schemaVersion: 2 → 3`):

```dart
@override
MigrationStrategy get migration => MigrationStrategy(
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(runs, runs.name);
        }
        if (from < 3) {
          await m.createTable(plans);
          await m.addColumn(taskRuns, taskRuns.planId);
        }
      },
    );
```

Reference plans are upserted at task-registry load time, idempotent on `(taskId, referenceVersion)`. A new `PlanDao` exposes:

```dart
Future<String> upsertReferencePlan(String taskId, ReferencePlan p);
Future<String> insertModelPlan(String taskId, String plannerModelId, String artifact);
Future<Plan?> planById(String id);
```

`RunDao.persistTaskRun` gains an optional `String? planId` parameter, set when present.

### 3.3 Stage-combination function

Lives in `lib/core/scoring.dart` next to `aggregate`:

```dart
double combineStages({
  required double planScore,    // null when single-stage
  required double executeScore,
  StageCombine mode = StageCombine.geometricMean,
}) {
  final p = planScore.clamp(0.01, 1.0);
  final e = executeScore.clamp(0.01, 1.0);
  return switch (mode) {
    StageCombine.geometricMean => sqrt(p * e),
    StageCombine.product => p * e,
    StageCombine.weightedSum =>
      0.5 * p + 0.5 * e, // weights sourced from settings in Phase A
  };
}

enum StageCombine { geometricMean, product, weightedSum }
```

**Rationale (preserved from brainstorm):**

- Geometric mean keeps the multiplicative property (a zero in either tanks the score) but stays on the same `[0, 1]` scale as single-shot scores, so leaderboards mix without rescaling.
- Floor-clamp `[0.01, 1.0]` reserves pure 0 for "no output" and prevents one judge wobble from collapsing the score.
- `mode` is a `StageCombine` enum routed through `EvaluatorConfig` (extended in Phase A). Phase B never reads `planScore` so combine is a no-op (`combineStages` is unused in B but ships now).

In Phase B, `aggregateScore` on `TaskRunResult` continues to be the execute-stage aggregate. Phase A introduces a `planAggregateScore` field on `TaskRunResult` (nullable; null for single-stage runs) and changes `aggregateScore` to `combineStages(planAggregateScore, executeAggregateScore)` when non-null.

### 3.4 Plan-prompt injection (Phase B)

The executor prompt template gains a single optional slot:

```
[task prompt as today]

REFERENCE PLAN:
The following plan was authored by a human and describes the intended
implementation approach. You should follow it; deviations are penalized.

```plan
{reference_plan_markdown}
```

[output instructions as today]
```

Implemented as a static formatter in `lib/runner/prompts/plan_aware_prompt.dart`:

```dart
String buildPromptWithPlan({
  required String taskPrompt,
  required String? planMarkdown, // null => returns taskPrompt unchanged
});
```

`RunBloc._onStart` calls this with `task.referencePlan?.markdown` when `event.useReferencePlan` is true, else passes `null`. The function is pure and trivially unit-tested.

### 3.5 `RunEvent` and `RunBloc` changes

`StartRun` gains:

```dart
final bool useReferencePlan;            // default false
```

`RunBloc._onStart` resolves `planId` per task per provider:

- If `event.useReferencePlan` and `task is MultiFileBenchmarkTask` and `task.referencePlan != null`: look up or insert the reference plan via `PlanDao`, attach `planId` to the `TaskRunResult`.
- Else: `planId = null`.

When persisting via `RunDao.persistTaskRun(planId: planId)`.

### 3.6 `NewRunPage` toggle

A `SwitchListTile` placed below the existing task selector. Behavior:

- **Disabled with caption** when no selected task has a `referencePlan` ("Select a planning task to enable.").
- **Enabled** when ≥ 1 selected task has a reference plan. When ON: tasks *without* a reference plan still run, but they don't receive a plan in their prompt (logged in `currentLabel` so users see what's happening).
- Default OFF. State held in `_NewRunPageState`.
- Propagated into `StartRunConfig.useReferencePlan` at Run-button-press.

A small `Tooltip` explains the trade-off ("Inject a curated reference plan into the prompt to isolate execution skill from planning skill").

### 3.7 New tasks (Phase B initial set)

Three tasks; two ship with full reference plans, one ships as a stub (placeholder fixture, plan present but execution not yet validated against expected outcome — included only to validate that the schema handles a third concurrent task).

#### `add_evaluator_type` (full)

- **Premise:** "Add a new `coverage` evaluator that reports test-coverage percentage as a 0–1 score."
- **Fixtures:** trimmed snapshot of `lib/evaluators/`, `lib/core/scoring.dart`, `pubspec.yaml`. ~8 files, ~1.5 KB total.
- **Output paths:** `lib/evaluators/coverage_evaluator.dart`, edits to `lib/core/scoring.dart` (add to `defaultEvaluatorWeights`), `test/evaluators/coverage_evaluator_test.dart`.
- **Reference plan:** ~300 words, markdown, sections "Files", "Steps", "Tests". Frozen at `referenceVersion: 1`.
- **Evaluators:** `compile`, `analyze`, `test` (runs the new test file the model writes), `diff_size`. No `llm_judge` in B.

#### `add_filter_dimension` (full)

- **Premise:** "Add a 'category' filter dimension to the leaderboard."
- **Fixtures:** trimmed snapshot of `lib/analytics/`, `lib/ui/pages/leaderboard_page.dart`, plus the relevant model classes. ~10 files, ~2 KB.
- **Output paths:** edits to `lib/analytics/leaderboard_filter.dart`, `lib/analytics/dimensions.dart`, `lib/ui/pages/leaderboard_page.dart`; new test file.
- **Reference plan:** ~350 words.
- **Evaluators:** `compile`, `analyze`, `test`, `diff_size`.

#### `refactor_run_bloc_cancellation` (stub for Phase B)

- Premise written; reference plan written; expected-outcome assertions left as TODO. Included so Phase B exercises a third task path through the schema. **Marked `@experimental`** in code; excluded from default task selection until expected outcomes are pinned in a follow-up commit.

Each task lives at `lib/tasks/planning_and_execution/<task_id>.dart` (Dart class) plus `assets/fixtures/planning_and_execution/<task_id>/` (fixture tree) plus `assets/plans/<task_id>.v1.md` (reference plan). Loaded via the existing `FixtureLoader` (extended to handle subdirectories) plus a new `PlanLoader` that reads from `rootBundle`.

### 3.8 Where Phase A plugs in

Phase A's mini-spec only needs to:

1. Introduce a `MultiStageBenchmarkTask` (plan stage + execute stage) — the existing `MultiFileBenchmarkTask` is the execute-stage shape; the plan stage is a new orchestration layer in `RunBloc`.
2. Add `plan_judge` and `plan_structure` evaluators, gated on the judge-validation harness passing.
3. Add `planAggregateScore` to `TaskRunResult` and switch `aggregateScore` to call `combineStages`.
4. Add a `planMode: planAware | referencePlan | none` enum to `StartRunConfig`, replacing the boolean `useReferencePlan`. The Phase B boolean is migrated trivially (`true → referencePlan`, `false → none`).

No Phase B decision blocks Phase A.

### 3.9 Where Phase C plugs in

Phase C's later spec only needs to:

1. Extend `StartRunConfig` with `plannerModel` and `executorModels` (lists), routed through `RunBloc` to drive the planner-then-executor cascade.
2. Add a pairing-matrix view under `lib/analytics/` reusing dimension infra.
3. Add a cost-preview component (`task_runs_count = M_p × M_e × N_tasks`) to `NewRunPage`.

The `Plans` table already supports `(plannerModelId, taskId)` lookups; no new schema.

## 4. Migration plan (file-by-file, Phase B only)

| File | Change |
|---|---|
| `lib/core/category.dart` | Add `Category.planningAndExecution`. |
| `lib/core/benchmark_task.dart` | Add `MultiFileBenchmarkTask` (extends `BenchmarkTask`) and `ReferencePlan` value object. |
| `lib/core/code_extractor.dart` | New `extractDartFiles(String) → Map<String, String>` parsing fenced blocks with `filename:` headers. Existing `extractDartCode` untouched. |
| `lib/core/scoring.dart` | Add `combineStages(...)` + `StageCombine` enum. Imports `dart:math` (`sqrt`). |
| `lib/storage/database.dart` | New `Plans` table; nullable `planId` column on `TaskRuns`. `schemaVersion: 3`. New migration step. |
| `lib/storage/database.g.dart` | Regenerated by Drift. |
| `lib/storage/dao/plan_dao.dart` | **New file.** `upsertReferencePlan`, `insertModelPlan`, `planById`. |
| `lib/storage/dao/run_dao.dart` | `persistTaskRun` accepts optional `planId` param, persists if non-null. |
| `lib/core/task_run_result.dart` | Add nullable `planId` field; `copyWith` if present. |
| `lib/runner/run_event.dart` | `StartRun` gains `useReferencePlan: bool` (default `false`); `props` updated. |
| `lib/runner/start_run_config.dart` | Add `useReferencePlan: bool` field. |
| `lib/runner/run_bloc.dart` | Inject reference plan into prompt via `buildPromptWithPlan`; resolve `planId` per task; pass to `persistTaskRun`. |
| `lib/runner/prompts/plan_aware_prompt.dart` | **New file.** `buildPromptWithPlan(...)`. |
| `lib/tasks/planning_and_execution/add_evaluator_type.dart` | **New file.** Class + fixtures + reference plan loading. |
| `lib/tasks/planning_and_execution/add_filter_dimension.dart` | **New file.** As above. |
| `lib/tasks/planning_and_execution/refactor_run_bloc_cancellation.dart` | **New file.** Stub task; reference plan only. Excluded from `task_catalog.dart` default registration; available via test-only registration helper. |
| `lib/tasks/task_catalog.dart` | Register the two full tasks. Stub task **not** registered. |
| `lib/core/fixture_loader.dart` | Extend to recursively load subdirectories under `assets/fixtures/<task_id>/`. |
| `lib/core/plan_loader.dart` | **New file.** `Future<ReferencePlan> loadReferencePlan(String assetPath, int version)` from `rootBundle`. |
| `assets/fixtures/planning_and_execution/<task_id>/...` | **New fixture trees** (per-task). |
| `assets/plans/<task_id>.v1.md` | **New reference plan files.** |
| `pubspec.yaml` | New asset paths under `flutter.assets`. No new dependencies. |
| `lib/ui/pages/new_run_page.dart` | New `SwitchListTile` for "Use reference plan"; binds `_useReferencePlan` state; propagates into `StartRunConfig`. Disabled-state caption logic. |
| `lib/runner/workdir_manager.dart` | New helper `createMultiFileTaskWorkdir(...)` writing each `Map<String, String> generatedFiles` entry to its path. Existing single-file path unchanged. |

**Files explicitly NOT touched:**

- `lib/analytics/dimensions.dart`, `lib/analytics/leaderboard_repository.dart`, `lib/analytics/leaderboard_filter.dart` — Phase 8 leaderboard view is deferred to Phase C; existing leaderboards filter by category and will simply omit `Category.planningAndExecution` until then.
- `lib/ui/pages/leaderboard_page.dart`, `lib/ui/pages/dashboard_page.dart` — same reason.
- `lib/evaluators/*` — no new evaluators in Phase B.

## 5. Testing strategy

### 5.1 Unit / widget tests added

1. `test/core/code_extractor_multi_file_test.dart` — parses a synthetic response with three `dart filename:` blocks; asserts the returned map keys/values; asserts robustness to extra whitespace and prose outside fences.
2. `test/core/scoring_combine_test.dart` — geometric-mean of `(0.5, 0.9) ≈ 0.671`; product yields `0.45`; clamping floor catches `0.0`.
3. `test/storage/plans_dao_test.dart` — upsert reference plan twice; verify single row; insert model plan; FK resolves; `TaskRuns.planId` round-trips.
4. `test/runner/prompts/plan_aware_prompt_test.dart` — null plan returns prompt unchanged; non-null plan inserts the fenced `` ```plan `` block exactly once; idempotent.
5. `test/runner/run_bloc_plan_aware_test.dart` — using a fake provider that records the prompt it received; assert prompt contains plan when `useReferencePlan = true`; assert prompt is identical to the no-plan path when `false`.
6. `test/tasks/planning_and_execution/add_evaluator_type_test.dart` — load fixtures, verify reference plan parses, verify expected paths set is well-formed.
7. `test/tasks/planning_and_execution/add_filter_dimension_test.dart` — same as above.
8. `test/ui/pages/new_run_page_plan_toggle_test.dart` — toggle disabled when no reference-plan task selected; enabling propagates into `StartRunConfig`.

### 5.2 Existing tests that need updating

- `test/runner/run_bloc_test.dart` — assertions on `StartRun.props` need `useReferencePlan` added; explicit-pass tests should pass `useReferencePlan: false` to keep behavior identical.
- `test/storage/dao/run_dao_test.dart` — `persistTaskRun` signature gains optional named param; existing call sites are source-compatible.
- `test/widget_test.dart` — no change expected unless `MaterialApp` smoke-test depends on schema.

### 5.3 What we do not test

- End-to-end "Run button → real LLM → plan executed correctly" — same as today; existing harness doesn't run real models in tests.
- Reference-plan *quality* (i.e., whether the human-authored plan is a good plan). Treated as canon.
- Phase A's plan-judge variance harness — that's *the* test of Phase A and will live with that mini-spec.

## 6. Risks and open questions

1. **Plan injection alters model behavior unevenly across providers.** Some models (e.g., reasoning models) may treat a markdown plan as constraints; others may treat it as suggestion. Phase B's leaderboard interpretation needs a caveat: scores compare execution-given-the-same-plan, not "ability to execute plans" in general. **Recommendation:** call this out in the README of the new category page when Plan 8 ships its own leaderboard view (Phase C); for B, document in the toggle's tooltip.

2. **Reference plans become benchmark canon.** A change to `assets/plans/add_evaluator_type.v1.md` invalidates historical runs against it. Mitigation: `referenceVersion` field on the plan; bumping it on edit means historical runs (with their persisted `planId`) still resolve to the old artifact. **Hard rule: never edit a published plan in place — bump version + insert new row.** Encoded in `PlanDao.upsertReferencePlan` (idempotent on `(taskId, version)`, so editing markdown without bumping version is a no-op and the divergence becomes visible).

3. **Multi-file output is harder to grade.** `add_evaluator_type` writes 3 files, including a test file. The test evaluator runs `dart test` against whatever the model produces — if the model writes a test that *only* verifies its own (potentially broken) implementation, the test passes regardless. Mitigation: each task's fixture tree includes a *hidden* test file (`test/_hidden/<task_id>_acceptance_test.dart`) that the workdir manager merges in *after* the model writes its files. The hidden test asserts properties the model can't game (e.g., the `coverage` evaluator's id is the string `'coverage'` and it's present in `defaultEvaluatorWeights`). **Spec note:** the hidden-test pattern is new but small (~30 LOC of `WorkdirManager` change). Flagged for review.

4. **Toggle UX is subtle.** "Use reference plan" applies *globally* to the run, but only some tasks have one. Mixed runs show ambiguous results. Mitigation: the toggle's label dynamically reads "Use reference plan (X of Y selected tasks)" so users see scope before clicking Run.

5. **Phase A's plan judge is high-variance and load-bearing.** Pinned in §2.2 as a *gate*: Phase A does not enable `plan_judge` in default weights until the validation harness passes. If the gate fails, fall back to `plan_structure` (cheap heuristics: presence of numbered steps, mention of files, mention of tests) plus execute-stage success as the only plan-quality signal. Worse, but not garbage.

6. **`Plans` table grows unboundedly.** Phase C with 5 planners × 10 tasks × N runs accumulates rows fast. For now: no GC. If it becomes a problem, a follow-up plan can add retention by `runId` cascade. Out of scope here.

7. **Stub task (`refactor_run_bloc_cancellation`) ships incomplete.** Why include it? Two reasons: (a) the registry/UI/storage code paths fail differently with 1 vs 3 tasks (e.g., toggle "X of Y" math is trivial with 2 — the third makes Y > 2 and surfaces off-by-ones), (b) it documents where the next task lands so the spec for the third task is just "fill in expected outcomes," not "extend the framework." Trade-off: a benchmark category that ships with one disabled task is mildly embarrassing. **Recommendation:** ship anyway, mark `@experimental`, exclude from default registration. If reviewer disagrees, drop it entirely and ship 2 tasks; nothing structural depends on the third.

8. **`code_extractor` change is purely additive but the prompt convention is a research bet.** `dart filename: lib/foo.dart` after the `dart` language tag is not standard markdown — it's our convention. Models may ignore the `filename:` hint and emit one big block. Mitigation: the executor prompt instructions explicitly demonstrate the convention with an example; if extraction fails, fall back to single-file behavior with a `WARNING:` note in the response details. We measure extraction-success rate as a side metric.

## 7. Implementation order (commit plan sketch)

This is a sketch — `writing-plans` will produce the formal task breakdown.

1. **Commit 1 — schema + DAO.** New `Plans` table, `planId` FK, migration to `schemaVersion: 3`, `PlanDao`, `RunDao` accepts `planId`. No behavior change yet.
2. **Commit 2 — task-shape extension.** `MultiFileBenchmarkTask`, `ReferencePlan`, `extractDartFiles`, `combineStages` (unused but landed). All untested-against-task; pure infra.
3. **Commit 3 — first task end-to-end.** `add_evaluator_type` task class, fixtures, reference plan, fixture-loader recursion, plan-loader, asset entries in `pubspec.yaml`. `RunBloc` ignores plan still; the task is reachable but reference-plan path inert.
4. **Commit 4 — plan injection.** `buildPromptWithPlan`, `RunEvent.useReferencePlan`, `StartRunConfig.useReferencePlan`, `RunBloc` wires plan into prompt and resolves `planId`. Tests for prompt construction.
5. **Commit 5 — UI toggle.** `NewRunPage` `SwitchListTile`, dynamic label, propagation. Widget tests.
6. **Commit 6 — second task.** `add_filter_dimension`, fixtures, plan, registration. Repeats the C3 pattern; validates the framework on a different shape.
7. **Commit 7 — stub third task + hidden-test plumbing.** `refactor_run_bloc_cancellation` stub class; `WorkdirManager` hidden-test merging; documented as experimental.

Each commit is independently shippable. Commits 1–2 are pure infra and ship even if the rest is held back.

## 8. See also

- `docs/roadmap/2026-05-03-plan-8-planning-and-execution.md` — source roadmap stub.
- `docs/specs/2026-05-03-plan-7-polish-design.md` — DI seam (`StartRunConfig`) this plan extends.
- `docs/plans/2026-05-02-evaluators-and-scoring.md` — `llm_judge` evaluator that Phase A's `plan_judge` will be modeled on.
- `docs/plans/2026-05-03-plan-6-analytics.md` — leaderboard / dimension infrastructure that Phase C's pairing-matrix view will extend.
- `docs/plans/2026-05-02-foundation-and-first-slice.md` — single-stage `BenchmarkTask` shape this extends additively (Option II in §3.1).
