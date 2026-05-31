# Plan 7 — Polish: Evaluator Weights Editor + DI Refactor (Design)

> **Status:** Draft design. Awaiting user review before implementation-plan authoring (writing-plans).
> **Source roadmap stub:** `docs/roadmap/2026-05-02-plan-7-polish.md`

## 1. Goal

Two small quality-of-life improvements bundled into one cohesive change:

1. **Evaluator weights editor** in the Settings page — let users override `defaultEvaluatorWeights` per evaluator id without editing source.
2. **Provider DI refactor** of the run-creation flow — pull `AppDatabase`, `RunDao`, `WorkdirManager`, `SettingsRepository`, and `RunBloc` construction out of the inline `_NewRunPageState._startRun` button handler and into a proper DI seam (`RepositoryProvider` + `BlocProvider` from `flutter_bloc`).

These two items are scoped together in one plan because **(1) is dead code without (2)**: today, `RunBloc.weights` defaults to `defaultEvaluatorWeights` and `_startRun` never reads `SettingsRepository.getEvaluatorWeights()`, so any saved override is silently ignored. The DI refactor is the natural place to wire saved weights into `RunBloc` at construction.

Side benefits:

- Widget tests for `NewRunPage`'s **Run button** path become viable for the first time (today the inline `AppDatabase()` construction in `_startRun` makes that path untestable).
- The current per-click `AppDatabase()` allocation leak is fixed as a natural consequence (one app-wide instance instead).

## 2. Scope

**In scope:**

- New "Evaluator Weights" section in `SettingsPage`, listing all evaluator ids enumerated by `defaultEvaluatorWeights.keys`. Each row: numeric `TextField` bound to the override, per-row "Reset" button, "Default" / "Override" `Badge`. Section footer: a compact normalized-distribution preview and a global "Reset all to defaults" button.
- DI refactor of the run-creation flow:
  - `AppDatabase`, `WorkdirManager`, `SettingsRepository` constructed once in `main.dart` (async), passed into `App`.
  - `App` wraps `MaterialApp.router` in `MultiRepositoryProvider` exposing those three plus a derived `RunDao(database)`.
  - `_NewRunPageState._startRun` reads dependencies via `context.read<T>()`, awaits `getEvaluatorWeights()`, builds a `StartRunConfig` value object, and navigates to `/run` with it as `state.extra`.
  - `RunProgressPage` accepts a `StartRunConfig`, hosts a `BlocProvider<RunBloc>` whose `create` synchronously builds `RunBloc(weights: extra.weights, ...)` from `context.read` repos, and dispatches `StartRun` in `initState`.
- Migration of `SettingsPage._SettingsPageState._repo` and the per-section repos to `context.read<SettingsRepository>()`. (We're already touching that file for the editor section.)
- Tests:
  - `test/ui/widgets/evaluator_weights_section_test.dart` — render rows, edit a value, reset row, reset-all, verify `setEvaluatorWeights` is called with expected payloads.
  - `test/ui/pages/new_run_page_test.dart` — extend with a fake `SettingsRepository`/`RunDao`/`WorkdirManager` provided via `MultiRepositoryProvider`, click Run, assert navigation occurred with a `StartRunConfig` containing the weights from the fake settings repo.
  - `test/runner/run_bloc_test.dart` — explicit assertion that `RunBloc(weights: customMap)` propagates the custom weights into `aggregate(...)`.

**Out of scope (explicit deferrals):**

- Migrating other ad-hoc `SettingsRepository()` constructors elsewhere in the codebase (e.g. inside `_JudgeSection`, `_OllamaLocalSection`, `_ApiKeySection`, `_ReadmeSection` subwidgets — those will keep their own constructors for now, but the page-level repo will come from `context.read`). Doing all sites in one pass is scope-creep; this plan migrates the touched files only.
- Per-task or per-category weight overrides.
- Disabling individual evaluators (weight = 0 is allowed; no special UI affordance).
- Slider-based weight UI.
- Schema changes.
- Documentation / README updates (per repo conventions).
- Refactoring `RunProgressPage`'s existing internals beyond the constructor signature change.

## 3. Architecture

### 3.1 Dependency graph (target state)

```
main.dart (async)
  ├── AppDatabase()                        [singleton, owns lifetime]
  ├── WorkdirManager(root: <appSupportDir>) [singleton, async-built]
  └── SettingsRepository()                  [singleton]
        │
        └── runApp(App(database, workdir, settings))

App.build(context):
  MultiRepositoryProvider(
    providers: [
      RepositoryProvider.value(value: database),
      RepositoryProvider.value(value: workdir),
      RepositoryProvider.value(value: settings),
      RepositoryProvider(create: (ctx) => RunDao(ctx.read<AppDatabase>())),
    ],
    child: MaterialApp.router(routerConfig: _router),
  )

/run route builder:
  (ctx, state) {
    final cfg = state.extra! as StartRunConfig;
    return BlocProvider<RunBloc>(
      create: (ctx) {
        final bloc = RunBloc(
          workdirManager: ctx.read<WorkdirManager>(),
          runDao: ctx.read<RunDao>(),
          weights: cfg.weights,
          now: () => DateTime.now(),
          idGenerator: _defaultIdGenerator,
        )..add(StartRun(
            tasks: cfg.tasks,
            providers: cfg.providers,
            modelByProvider: cfg.modelByProvider,
            evaluatorConfig: cfg.evaluatorConfig,
            name: cfg.name,
          ));
        return bloc;
      },
      child: const RunProgressPage(),
    );
  }
```

### 3.2 `StartRunConfig` value object

A new immutable data class carries the resolved run configuration from `NewRunPage` to `RunProgressPage` via `state.extra`. It exists so the `BlocProvider.create` inside the route builder can be synchronous (no `await` inside route construction).

```dart
// lib/runner/start_run_config.dart
class StartRunConfig {
  const StartRunConfig({
    required this.tasks,
    required this.providers,
    required this.modelByProvider,
    required this.evaluatorConfig,
    required this.weights,
    this.name,
  });

  final List<BenchmarkTask> tasks;
  final List<ModelProvider> providers;
  final Map<String, String> modelByProvider;
  final EvaluatorConfig evaluatorConfig;
  final Map<String, double> weights;
  final String? name;
}
```

`NewRunPage._startRun` constructs this object after `await`-ing both the judge config and the weights, then navigates with it. `RunProgressPage` receives it via constructor (and reads it from `state.extra` in the route builder).

**Why a value object instead of passing the bloc itself (current pattern):**

- Keeps `RunBloc` construction inside the `BlocProvider` lifecycle (auto-dispose on route pop).
- Removes `RunBloc` from the `Widget` constructor surface — `RunProgressPage` becomes a `const` widget that reads its bloc via `context.read`.
- The "extra is a config, not a live object" pattern is more idiomatic for `go_router` and easier to extend (e.g., Plan 8 will add a `referencePlanVersion` field).

### 3.3 `EvaluatorWeightsSection` widget

A self-contained `StatefulWidget` extracted into `lib/ui/widgets/evaluator_weights_section.dart` so it can be widget-tested independently of `SettingsPage`.

**Public surface:**

```dart
class EvaluatorWeightsSection extends StatefulWidget {
  const EvaluatorWeightsSection({super.key, this.repo});
  final SettingsRepository? repo; // optional override for tests; defaults to context.read
}
```

**Rendering:**

- One `Card` containing a `Column` of:
  - `Text('Evaluator Weights', ...)` heading.
  - One row per `evaluatorId` in `defaultEvaluatorWeights.keys`:
    - Leading: `Text(evaluatorId)` (monospace).
    - Center: `TextField` with `keyboardType: TextInputType.numberWithOptions(decimal: true)`, validated as a non-negative double. Empty input is treated as "no override" (i.e., revert to default).
    - Trailing: `Badge(label: Text(isOverride ? 'Override' : 'Default'))`, color-coded the same way the API-key sections do (`Colors.green` / `Colors.orange`).
    - Far trailing: `IconButton(icon: Icons.refresh)` — clears that single row's override.
  - Divider.
  - Normalized-distribution preview: a single horizontal stacked bar (a `Row` of flex-weighted `Container`s with distinct colors, no `fl_chart` dependency) plus a `Wrap` of `Chip(label: Text('compile 12%'))` underneath. Updates live as the user edits.
  - "Reset all to defaults" `OutlinedButton`.
  - "Save" `FilledButton` that writes the current override map to `setEvaluatorWeights(overrides)` and shows a `SnackBar`.

**State model:**

```dart
class _EvaluatorWeightsSectionState extends State<EvaluatorWeightsSection> {
  late final SettingsRepository _repo;
  final Map<String, TextEditingController> _controllers = {};
  Map<String, double> _saved = const {}; // last-loaded effective weights (default ∪ overrides)
  bool _loading = true;
}
```

`_load()`:
- Calls `_repo.getEvaluatorWeights()` once on `initState`.
- Returned map is the effective map (defaults merged with overrides). Controller text for each row is set to the effective value.
- `_saved` records the snapshot for "isOverride" comparison: a row is in "Override" state iff its current text parses to a value ≠ `defaultEvaluatorWeights[id]`.

`_save()`:
- For each row, parse the text. If parsed value equals `defaultEvaluatorWeights[id]` (within an epsilon of `1e-9`), omit it from the overrides map; otherwise include it.
- Persist via `_repo.setEvaluatorWeights(overrides)`.

`_resetRow(id)`:
- Set the controller text to `defaultEvaluatorWeights[id].toString()`. Does not auto-save — user must press Save.

`_resetAll()`:
- For every row, set controller text to default. Does not auto-save.

**Validation:**

- **Empty input** is **valid** and means "no override" (the row falls back to `defaultEvaluatorWeights[id]` for both display in the preview and the eventual save).
- **Non-empty input that doesn't parse as `double`** or parses to a **negative** value disables the Save button and shows red helper text on the offending row.
- `0.0` is valid (means "evaluator contributes nothing" — equivalent to disabling it).
- Sum-to-1 normalization is **not** enforced. The aggregation in `scoring.dart` already normalizes by dividing by the weight sum (`num / den`), so absolute magnitudes don't matter — only ratios. The preview's percentage display reinforces this.

### 3.4 Where `SettingsRepository.getEvaluatorWeights()` is consumed

After this plan, exactly one place reads it for run-time effect: `_NewRunPageState._startRun`, immediately before constructing `StartRunConfig`. The `EvaluatorWeightsSection` reads it for editing, but that's a UI-side concern.

`RunBloc.weights` keeps its `defaultEvaluatorWeights` constructor default — call sites that don't care (e.g. unit tests) continue to get the default. Production code goes through `StartRunConfig.weights` which is loaded from settings.

`lib/analytics/dimensions.dart` currently uses `defaultEvaluatorWeights` directly. We **do not** change that here. Analytics historical comparisons should be reproducible across weight changes; baking saved overrides into analytics would mean the leaderboard shifts every time the user edits a slider. Opening that question is out of scope — flagged in §6.

## 4. Migration plan (file-by-file)

| File                                       | Change                                                                                                                                                   |
|--------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `lib/main.dart`                            | Becomes `Future<void> main() async`. Builds `AppDatabase`, `WorkdirManager`, `SettingsRepository`. Passes them to `App(...)`.                            |
| `lib/app.dart`                             | `App` takes `database`, `workdir`, `settings` as constructor params. Wraps `MaterialApp.router` in `MultiRepositoryProvider`. `/run` route builder switches to `BlocProvider`-creates-`RunBloc` from `state.extra` `StartRunConfig`. |
| `lib/ui/pages/new_run_page.dart`           | `_startRun` no longer constructs `AppDatabase`/`RunDao`/`WorkdirManager`/`RunBloc`. Reads via `context.read`, awaits `getEvaluatorWeights()`, builds `StartRunConfig`, navigates with `goRouter.push('/run', extra: config)`. |
| `lib/ui/pages/run_progress_page.dart`      | Constructor changes from `RunProgressPage({required this.bloc})` to `const RunProgressPage()`. Bloc accessed via `context.read<RunBloc>()`. The widget's existing internal logic is otherwise untouched. |
| `lib/ui/pages/settings_page.dart`          | `_SettingsPageState._repo` removed. `_repo` reads come from `context.read<SettingsRepository>()`. New `_EvaluatorWeightsSection` slot added between `_JudgeSection` and `_OllamaLocalSection`. |
| `lib/ui/widgets/evaluator_weights_section.dart` | **New file.** Implementation per §3.3.                                                                                                              |
| `lib/runner/start_run_config.dart`         | **New file.** Value object per §3.2.                                                                                                                     |
| `lib/runner/run_bloc.dart`                 | No source change. `weights` constructor parameter and default already exist.                                                                             |

**Files explicitly NOT touched** (despite containing `SettingsRepository()` constructions):

- The four `_*Section` subwidgets inside `settings_page.dart` (`_JudgeSection`, `_OllamaLocalSection`, `_ApiKeySection`, `_ReadmeSection`) — they each construct their own `SettingsRepository` / receive one via constructor. We migrate the page-level state's repo only. Migrating the subwidgets is mechanical follow-up work.
- Any other UI page or service that constructs `SettingsRepository()` ad-hoc — none currently exist outside of `new_run_page.dart` (covered) and the settings sections (deferred).

## 5. Testing strategy

### 5.1 Unit / widget tests added

1. **`test/ui/widgets/evaluator_weights_section_test.dart`** (new):
   - `setUp`: `FlutterSecureStorage.setMockInitialValues({})`.
   - Test: renders one row per evaluator id from `defaultEvaluatorWeights.keys`.
   - Test: editing a row's `TextField` flips its badge from "Default" to "Override".
   - Test: pressing the per-row Reset button restores the default value and flips the badge back.
   - Test: pressing Save calls `setEvaluatorWeights` with only the rows whose values differ from defaults (and *not* with rows that match defaults).
   - Test: invalid input (negative, non-numeric) disables the Save button.
   - Test: "Reset all" sets every row to its default value (does not persist until Save is pressed).

2. **`test/ui/pages/new_run_page_test.dart`** (extended):
   - New helper to wrap `NewRunPage` in `MultiRepositoryProvider` with fake `SettingsRepository`, `RunDao`, `WorkdirManager`. (No `AppDatabase` fake needed — the test provides `RunDao` directly, bypassing the `RunDao(ctx.read<AppDatabase>())` factory used in production.)
   - New test: clicking Run with at least one task and one provider builds a `StartRunConfig` whose `weights` map equals what the fake `SettingsRepository.getEvaluatorWeights()` returned.
   - Existing tests continue to pass with the new wrapper.

3. **`test/runner/run_bloc_test.dart`** (extended):
   - One new test: a `RunBloc` constructed with a custom `weights` map produces an `aggregateScore` consistent with that map (using a stub task + stub provider returning known evaluator results).

### 5.2 Existing tests that need updating

- `test/widget_test.dart` (root): probably needs to construct `App(database: ..., workdir: ..., settings: ...)` with fakes. Since the existing test is minimal (likely a smoke test), the patch is small.
- Any test that imports `RunProgressPage` and constructs it with a `bloc` argument: switch to wrapping in a `BlocProvider.value(value: bloc, child: const RunProgressPage())`.

### 5.3 What we do not test

- The actual `flutter_secure_storage` round-trip beyond what `FlutterSecureStorage.setMockInitialValues` already exercises (other settings sections already follow this pattern; we don't reinvent it).
- End-to-end "click Run, run completes" — the runner already has bloc-level coverage and the existing widget tests don't cover the runner path either. Adding it is bigger scope than this plan.

## 6. Risks and open questions

1. **Should saved weights also affect analytics (Plan 6 dimensions)?** Currently `Dimensions.fromTaskRuns` uses `defaultEvaluatorWeights` directly. If we route saved overrides into analytics, historical leaderboards shift whenever the user edits weights — confusing. If we don't, the user can edit weights and see a *new* run scored under those weights but old runs still scored under defaults. **Recommendation: do not change analytics in this plan.** Surface the question in the design review and defer to a follow-up if needed.

2. **`RunBloc` lifecycle change.** Today the bloc is constructed on the `NewRunPage` side and pushed as `state.extra`. After the refactor, it lives inside `BlocProvider` on the `/run` route. If a user navigates back from `/run` to `/new-run` and then back to `/run` somehow (unlikely with `push`), they'd get a new bloc — which is correct. But: the `BlocProvider.create` dispatches `StartRun` in its body; if `RunProgressPage` is rebuilt (e.g., hot reload) the bloc isn't recreated (BlocProvider caches by default), so `StartRun` won't fire twice. Verified by reading `flutter_bloc` semantics; flagged for review.

3. **`AppDatabase` lifecycle.** Moving to a single app-wide instance means it's never explicitly closed. For a desktop Flutter app this is fine (Drift cleans up on process exit). If we ever ship to a platform with stricter lifecycle requirements (foldable Android resume, etc.), this needs reconsidering. Out of scope here.

4. **Migration of subwidget `_repo` instances inside `settings_page.dart`.** Leaving them is *correct but not pretty*. Future PRs can mop them up. Calling this out so reviewers don't think the refactor is incomplete by accident.

5. **`getEvaluatorWeights()` failure.** If secure storage throws on read (rare but possible), `_NewRunPageState._startRun` should fall back to `defaultEvaluatorWeights` rather than blocking the run. **Recommendation: try/catch with a `debugPrint` in non-release builds.** Spec implementation note: the catch site is `_startRun`, not the section widget — the section can show a load error inline.

6. **`flutter_bloc` 8.x vs 9.x.** Repo uses `^8.1.6`. `RepositoryProvider.value` and `MultiRepositoryProvider` are stable on 8.x; no version bump needed.

## 7. Implementation order (commit plan sketch)

This is a sketch — `writing-plans` will produce the formal task breakdown.

1. **Commit 1 — DI plumbing only** (no behavior change).
   - Add `MultiRepositoryProvider` in `app.dart`. Pass repos in from `main.dart`.
   - `NewRunPage._startRun` reads via `context.read` but still constructs `RunBloc` inline as today. `getEvaluatorWeights()` not yet wired.
   - All existing tests must pass with no functional change.

2. **Commit 2 — `StartRunConfig` + `RunBloc` via `BlocProvider`.**
   - Introduce `StartRunConfig`. Refactor `RunProgressPage` to drop the `bloc` constructor param. Migrate the route to use `BlocProvider`.
   - Now the inline `RunBloc` construction is gone. Still using `defaultEvaluatorWeights`.

3. **Commit 3 — wire saved weights.**
   - `_startRun` `await`s `SettingsRepository.getEvaluatorWeights()` and passes to `StartRunConfig.weights`. Now saved weights take effect.
   - This is the smallest possible "fix the dead-code bug" diff; reviewers can see it isolated.

4. **Commit 4 — `EvaluatorWeightsSection` widget + tests.**
   - New file + tests. Not yet wired into `SettingsPage`.

5. **Commit 5 — wire `EvaluatorWeightsSection` into `SettingsPage`.**
   - Adds the section. Migrates `_SettingsPageState._repo` to `context.read<SettingsRepository>()` for consistency.

Each commit is independently shippable and reviewable. The order is chosen so that even if the editor (4–5) is held back for review, commits 1–3 ship the dead-code fix on their own.

## 8. See also

- `docs/roadmap/2026-05-02-plan-7-polish.md` — source roadmap stub.
- `docs/plans/2026-05-02-evaluators-and-scoring.md` — defines `defaultEvaluatorWeights` and the secure-storage settings keys.
- `docs/plans/2026-05-02-foundation-and-first-slice.md` — Task 17 (NewRunPage) explicitly notes "Plan 4 will refactor this with proper provider DI." This plan is the delivery on that promise.
- `docs/roadmap/2026-05-03-plan-8-planning-and-execution.md` — depends on this plan's DI seam (RunBloc construction must be clean before adding multi-stage tasks).
