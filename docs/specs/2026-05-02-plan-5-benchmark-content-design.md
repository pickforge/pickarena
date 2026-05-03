# Plan 5 — Benchmark Content: 9 New Tasks (Design)

> **Status:** Approved design. Ready for implementation-plan authoring (writing-plans).
> **Source roadmap stub:** `docs/roadmap/2026-05-02-plan-5-benchmark-content.md`

## 1. Goal

Grow the benchmark suite from 1 task to 10 by adding 9 new `BenchmarkTask` implementations across the 5 existing categories. Each new task ships with: fixtures (skeleton/broken/working Dart code + the right tests for its grading shape), a prompt, a judge rubric, and a configured set of evaluators via `evaluatorsFor(EvaluatorConfig)`.

## 2. Scope

**In scope:**

- 9 new task classes, each with its own fixture asset tree.
- A small, shared `FixtureLoader` helper used by all 10 tasks (the existing one is migrated).
- A tiny lifecycle hook on `BenchmarkTask` (`ensureLoaded`) so `task_catalog.dart` does not need to know per-task asset loading details.
- A `BenchmarkTask.isFlutter` flag (default `false`) so `WorkdirManager.prepare`, `CompileEvaluator`, and `TestEvaluator` can dispatch to `flutter` instead of `dart` for Flutter fixtures.
- Per-task pubspec asset wiring in the host app's `pubspec.yaml`.
- Registration of all 10 tasks in `buildDefaultTaskRegistry()`.

**Out of scope:**

- UI changes (multi-task selection, history filters, etc. — Plan 4 territory).
- New evaluators (the 6 from Plan 3 are sufficient).
- New providers.
- Multi-file model output (collapsed to single-file per task; see §3.4).
- Analytics or cross-task aggregation (Plan 6 territory).
- Documentation/README updates (per repo conventions).

## 3. Architecture

### 3.1 Shared infrastructure

#### `FixtureLoader` (new)

A tiny helper that loads a known list of relative asset paths into a `Map<String, String>` keyed by the relative path inside the fixture. No magic, no recursion — just kills the `loadAssets()` boilerplate.

```dart
// lib/core/fixture_loader.dart
class FixtureLoader {
  FixtureLoader({required this.assetRoot, required this.files});

  final String assetRoot;
  final List<String> files;

  Future<Map<String, String>> load() async {
    final out = <String, String>{};
    for (final rel in files) {
      out[rel] = await rootBundle.loadString('$assetRoot/$rel');
    }
    return out;
  }
}
```

Each `BenchmarkTask` subclass owns its `fixtures` map but populates it through a single `FixtureLoader` call inside `ensureLoaded`. The existing `OffByOnePaginationTask` is migrated as part of step 1; behavior is unchanged.

#### `BenchmarkTask.ensureLoaded` lifecycle hook

`BenchmarkTask` gains a default `Future<void> ensureLoaded() async {}`. Tasks that need asset loading override it. The startup path that currently calls `OffByOnePaginationTask.loadAssets()` ad-hoc becomes:

```dart
final registry = buildDefaultTaskRegistry();
for (final task in registry.all) {
  await task.ensureLoaded();
}
```

This makes the catalog file free of per-task knowledge of how fixtures are loaded.

#### `BenchmarkTask.isFlutter` dispatch flag

`BenchmarkTask` gains `bool get isFlutter => false;`. Flutter-fixture tasks override it. The runner and the existing Dart-based evaluators read it and dispatch to the right binary:

- `WorkdirManager.prepare`: `flutter pub get` if `task.isFlutter`, else `dart pub get` (with offline-first behavior preserved).
- `CompileEvaluator`: `flutter analyze --fatal-infos` if `task.isFlutter`, else `dart analyze --fatal-infos`.
- `TestEvaluator`: `flutter test --reporter=json` if `task.isFlutter`, else `dart test --reporter=json`.

`WidgetTreeEvaluator` already uses `flutter` and is unchanged. The runner already passes `task` into `EvaluationContext`, and `WorkdirManager.prepare` is updated to accept the task (or its `isFlutter` flag) at call time.

Tasks where `isFlutter == true`: `ui.profile_card`, `ui.expandable_list_tile`, `refactor.god_widget`, `test.todo_input`, `test.form_validation`. Pure-Dart tasks (`isFlutter == false`): `bug.off_by_one_pagination`, `state.counter_bloc`, `state.shopping_cart_bloc`, `refactor.callback_hell`, `bug.async_race_condition`. The bloc fixtures depend on the pure-Dart `bloc` package (not `flutter_bloc`) to keep them out of the Flutter toolchain. The flag is set per task at the class level.

### 3.2 Uniform task file layout

```
lib/tasks/<category>/<task_id>.dart                 # BenchmarkTask subclass
lib/tasks/<category>/fixtures/<task_id>/
  pubspec.yaml                                      # standalone Dart/Flutter project
  lib/<thing>.dart                                  # SUT (broken, skeleton, or working)
  test/<thing>_test.dart                            # oracle / behavior-pinning tests
  test/_reference/<thing>_reference_test.dart       # only for test-author tasks
```

`<category>` is the snake_case folder name aligning with `Category` enum: `bug_fix`, `state_management`, `ui_from_spec`, `refactor`, `widget_testing`.

### 3.3 Three grading shapes

All 10 tasks fall into one of three shapes:

| Shape | Used by | Fixture provides | Evaluators (when `hasJudge`) |
|---|---|---|---|
| **Oracle-graded** | UI from spec, state mgmt | empty/skeleton SUT + oracle tests already written | compile + analyze + test + judge + diff |
| **Regression-graded** | refactor, bug fix | broken/messy SUT + behavior-pinning tests | compile + analyze + test + judge + diff |
| **Test-author** | widget testing | working SUT + hidden reference test suite under `test/_reference/` | compile + analyze + test (model's tests) + widget_tree (reference suite) + judge + diff |

The test-author shape is the only one that needs anything beyond the existing evaluator set, and even then no code changes — just per-task configuration of `WidgetTreeEvaluator(testDir: 'test/_reference')`.

### 3.4 Single-file output constraint

`BenchmarkTask.generatedCodePath` stays a single string. Every new task collapses to one Dart file:

- Bloc tasks: bloc + events + states in one library file.
- Widget test tasks: one `*_test.dart` file. SUT and reference suite are pre-seeded.
- Refactor tasks: model rewrites the single smelly file.

If a task feels like it really needs multi-file output, that is a signal to either pre-seed the supporting files in the fixture or to defer the task.

## 4. Per-task catalog

Sequencing matches §5.1 (implementation order).

### 4.1 `bug.off_by_one_pagination` *(existing — migrated)*

Already implemented. Behavior unchanged. Only the asset-loading path is rewritten to use `FixtureLoader`. Score parity verified before moving on.

### 4.2 `state.counter_bloc` — Regression-graded baseline

- **Prompt:** Implement `CounterBloc` (single file) supporting `Increment`, `Decrement`, `Reset` events with a non-negative invariant (`Decrement` at 0 stays at 0).
- **Fixture:** `lib/counter_bloc.dart` (skeleton with class signature + TODO bodies); `test/counter_bloc_test.dart` (oracle: emits expected sequences, respects invariant).
- **Output:** `lib/counter_bloc.dart`.
- **Evaluators:** compile + analyze + test + judge + diff.
- **Rubric focus:** correct invariant handling, idiomatic event/state pattern, no extra public API.

### 4.3 `state.shopping_cart_bloc` — Oracle-graded, larger surface

- **Prompt:** Implement `ShoppingCartBloc` in one file: add/remove/update-quantity events; state exposes line items, subtotal, item count; quantity 0 removes the item.
- **Fixture:** `lib/cart_bloc.dart` (skeleton); `test/cart_bloc_test.dart` (oracle with edge cases: duplicate adds merge, qty 0 removal, total recalculation).
- **Output:** `lib/cart_bloc.dart`.
- **Evaluators:** compile + analyze + test + judge + diff.
- **Rubric focus:** correctness across edge cases, immutable state, sensible domain modeling.

### 4.4 `ui.profile_card` — Oracle-graded UI

- **Prompt:** Build a `ProfileCard` widget matching a textual spec (avatar leading, name + handle, optional bio, follow button at the trailing edge; accessible labels). Single stateless widget.
- **Fixture:** `lib/profile_card.dart` (empty class signature only); `test/profile_card_test.dart` (widget tests asserting `find.byType(CircleAvatar)`, name text, button presence, accessibility semantics, layout direction).
- **Output:** `lib/profile_card.dart`.
- **Evaluators:** compile + analyze + test + judge + diff.
- **Rubric focus:** spec coverage point-by-point, idiomatic Flutter composition, accessibility.

### 4.5 `ui.expandable_list_tile` — Oracle-graded UI with state

- **Prompt:** Stateful `ExpandableListTile` widget: collapsed shows title + chevron; tap toggles to expanded showing details; animates rotation of chevron; calls `onExpansionChanged`.
- **Fixture:** `lib/expandable_list_tile.dart` (stub); `test/expandable_list_tile_test.dart` (asserts initial collapsed state, tap-to-expand, callback fired with correct value, chevron rotation widget present).
- **Output:** `lib/expandable_list_tile.dart`.
- **Evaluators:** compile + analyze + test + judge + diff.
- **Rubric focus:** correct local state transitions, proper widget lifecycle, animation present (not necessarily perfect).

### 4.6 `refactor.god_widget` — Regression-graded

- **Prompt:** Refactor a 200+ line `GodWidget` (mixed UI + business logic + state) into smaller focused widgets and pure helpers within the same file. Public API and behavior must be unchanged.
- **Fixture:** `lib/god_widget.dart` (the smell); `test/god_widget_test.dart` (behavior-pinning tests covering rendered output and interactions).
- **Output:** `lib/god_widget.dart`.
- **Evaluators:** compile + analyze + test + judge + diff. `DiffSize` is informational only (refactors are *expected* to be large).
- **Rubric focus:** clear separation of concerns, no leaked private types in public API, naming, no behavior drift.

### 4.7 `refactor.callback_hell` — Regression-graded

- **Prompt:** Refactor a deeply nested callback chain (chained `.then` and nested anonymous fns) into clean `async`/`await`. Single file, public API preserved.
- **Fixture:** `lib/data_pipeline.dart` (the chain); `test/data_pipeline_test.dart` (behavior tests with mocked async deps verifying ordering and error propagation).
- **Output:** `lib/data_pipeline.dart`.
- **Evaluators:** compile + analyze + test + judge + diff.
- **Rubric focus:** correct error propagation, ordering preserved, async/await idiom.

### 4.8 `test.todo_input` — Test-author shape

- **Prompt:** Write a `widgetTest` suite for `TodoInput` widget covering: empty input disables submit; non-empty enables; submit clears the field and fires `onSubmit`; respects max length. Single test file.
- **Fixture:** `lib/todo_input.dart` (working SUT, do not modify); `test/_reference/todo_input_reference_test.dart` (hidden reference tests known to pass against the SUT).
- **Output:** `test/todo_input_test.dart`.
- **Evaluators:** compile + analyze + test (model's suite must pass) + `WidgetTreeEvaluator(testDir: 'test/_reference')` (must still pass — guards against the model touching SUT) + judge + diff.
- **Rubric focus:** assertion coverage of each spec bullet, correct use of `pumpWidget` and finders, no flakiness patterns.

### 4.9 `test.form_validation` — Test-author shape

- **Prompt:** Write widget tests for a `SignupForm` validating: required email and password fields, email format check, password min length, error messages shown on invalid submit, submit disabled until valid.
- **Fixture:** `lib/signup_form.dart` (working SUT); `test/_reference/signup_form_reference_test.dart`.
- **Output:** `test/signup_form_test.dart`.
- **Evaluators:** same as §4.8 (test-author shape).
- **Rubric focus:** comprehensive validation case coverage, proper use of `Form` + validator finders, negative cases included.

### 4.10 `bug.async_race_condition` — Regression-graded, hardest fixture

- **Prompt:** Fix the race condition in `lib/search_controller.dart`: rapid query changes can cause stale results to overwrite fresh ones. Preserve public API; keep stream-based control flow.
- **Fixture:** `lib/search_controller.dart` (broken: ignores request generation/cancellation); `test/search_controller_test.dart` (failing tests using `fake_async` to deterministically reproduce the race; correct fix makes them all pass).
- **Output:** `lib/search_controller.dart`.
- **Evaluators:** compile + analyze + test + judge + diff.
- **Rubric focus:** correctness of the fix (most important), minimal surface, no busy-waiting, idiomatic cancellation pattern.

### 4.11 Summary table

| # | Task ID | Category | Shape | Has widget_tree | Output path |
|---|---|---|---|---|---|
| 1 | bug.off_by_one_pagination | bugFix | regression | no | lib/pagination.dart |
| 2 | state.counter_bloc | stateMgmt | regression | no | lib/counter_bloc.dart |
| 3 | state.shopping_cart_bloc | stateMgmt | oracle | no | lib/cart_bloc.dart |
| 4 | ui.profile_card | uiFromSpec | oracle | no | lib/profile_card.dart |
| 5 | ui.expandable_list_tile | uiFromSpec | oracle | no | lib/expandable_list_tile.dart |
| 6 | refactor.god_widget | refactor | regression | no | lib/god_widget.dart |
| 7 | refactor.callback_hell | refactor | regression | no | lib/data_pipeline.dart |
| 8 | test.todo_input | widgetTesting | test-author | yes (reference) | test/todo_input_test.dart |
| 9 | test.form_validation | widgetTesting | test-author | yes (reference) | test/signup_form_test.dart |
| 10 | bug.async_race_condition | bugFix | regression | no | lib/search_controller.dart |

UI tasks rely on widget tests via standard `TestEvaluator` (since each fixture is a Flutter project). They do not need a separate reference suite, so `WidgetTreeEvaluator` is not wired for them.

## 5. Rollout

### 5.1 Implementation order

Ordered by risk: shared infra first; lowest-risk task next; trickiest fixture last. Each step is independently verifiable.

1. **Shared infra** — add `FixtureLoader`, `BenchmarkTask.ensureLoaded`, and `BenchmarkTask.isFlutter`; thread the flag through `WorkdirManager.prepare`, `CompileEvaluator`, and `TestEvaluator`; migrate `OffByOnePaginationTask`. **Checkpoint:** existing run produces identical scores.
2. **`state.counter_bloc`** — pure Dart, regression-graded. **Checkpoint:** task in registry; manual run against one provider yields green compile + analyze + test + judge.
3. **`state.shopping_cart_bloc`** — same shape, broader surface.
4. **`ui.profile_card`** — first Flutter fixture. **Checkpoint:** materialize fixture and run `flutter test` locally before any model attempts it.
5. **`ui.expandable_list_tile`** — stateful widget + animation.
6. **`refactor.god_widget`** — first regression-graded refactor. **Checkpoint:** behavior tests pass against the broken-but-functional smelly code; a hand-written refactor still passes them.
7. **`refactor.callback_hell`** — async refactor.
8. **`test.todo_input`** — first test-author shape. **Checkpoint:** reference suite passes against unmodified SUT; deliberately weak model output yields a low but non-zero score with no evaluator crash.
9. **`test.form_validation`** — second test-author task.
10. **`bug.async_race_condition`** — hardest fixture. **Checkpoint:** with broken code, tests fail deterministically; with one hand-written correct fix, they pass deterministically across 10 consecutive runs.

### 5.2 Registry wiring

`lib/tasks/task_catalog.dart`:

```dart
TaskRegistry buildDefaultTaskRegistry() {
  final registry = TaskRegistry();
  registry.register(OffByOnePaginationTask());
  registry.register(AsyncRaceConditionTask());
  registry.register(CounterBlocTask());
  registry.register(ShoppingCartBlocTask());
  registry.register(ProfileCardTask());
  registry.register(ExpandableListTileTask());
  registry.register(GodWidgetTask());
  registry.register(CallbackHellTask());
  registry.register(TodoInputTestTask());
  registry.register(FormValidationTestTask());
  return registry;
}
```

Tasks are added as they land so partial merges still ship value.

### 5.3 Asset registration

Flutter does not recurse asset directories, so each subdirectory containing files needs its own `flutter > assets:` line. Each task contributes `<root>/`, `<root>/lib/`, `<root>/test/`, and where applicable `<root>/test/_reference/`. Per-task implementation steps explicitly enumerate the lines to add to keep this hard to forget.

## 6. Acceptance criteria (definition of done)

1. `flutter analyze` and the existing test suite pass; no regressions to evaluators or runner.
2. `buildDefaultTaskRegistry()` returns 10 tasks; the run page picks them up automatically (no UI changes required).
3. Each of the 10 tasks, when run end-to-end with a real provider configured for both candidate and judge, completes without throwing and produces a non-null final score.
4. Each task's fixture, in its broken/skeleton state, has the expected failing tests (or, for oracle tasks, the SUT is a stub that fails compile or oracle).
5. Each task's fixture, given a hand-written correct reference solution, scores ≥ 0.9 when run with all evaluators including judge.
6. Each task's fixture, given a deliberately weak/incorrect output (e.g. empty class, no-op widget), produces a low score (< 0.3) and does not crash any evaluator.
7. The reference suite for both `test.*` tasks passes against the unmodified SUT.
8. No README/docs updates as part of this plan.

## 7. Risks & open questions

- **Asset bundle size.** 9 new fixtures × small files is fine, but worth a sanity check after step 6.
- **Determinism of `async_race_condition` test.** May require `fake_async` package — added to that fixture's pubspec only.
- **Judge cost during dev.** Acceptance criteria 5 and 6 use a real judge: ~10 tasks × 1 sample each per direction. Manageable, but flag during execution.
- **`flutter` binary availability** for `WidgetTreeEvaluator` and Flutter fixtures: already a hard requirement of the project, restated here.

## 8. See also

- `docs/plans/2026-05-02-foundation-and-first-slice.md` — `OffByOnePaginationTask` is the reference shape.
- `docs/plans/2026-05-02-evaluators-and-scoring.md` — defines the 6 evaluators these tasks compose.
- `docs/roadmap/2026-05-02-plan-5-benchmark-content.md` — original roadmap stub.
