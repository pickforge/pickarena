# Plan 7 (roadmap stub) — Polish: Evaluator Weights Editor + DI Refactor

> **Status:** Roadmap stub. Not yet specced. Brainstorm + write the full plan doc when ready to start.

## Goal

Two small quality-of-life improvements that don't fit cleanly into the data-, content-, or analytics-themed plans:

1. **Evaluator weights editor** in the Settings page so users can override `defaultEvaluatorWeights` per evaluator id without editing source.
2. **Provider DI refactor** of `NewRunPage` to remove the inline `AppDatabase`/`RunDao`/`WorkdirManager`/`RunBloc` construction and inject them via a proper DI seam (likely top-level `Provider`/`RepositoryProvider` from `flutter_bloc`).

## Scope

### Evaluator weights editor

- New section in `SettingsPage` listing each known evaluator id (`compile`, `analyze`, `test`, `widget_tree`, `llm_judge`, `diff_size`) with a `Slider` or numeric `TextField` bound to `SettingsRepository.getEvaluatorWeights` / `setEvaluatorWeights`.
- "Reset to defaults" action.
- Live preview of the resulting normalized weight distribution.

### Provider DI refactor

- Pull `AppDatabase`, `RunDao`, `WorkdirManager`, `SettingsRepository` construction out of `_NewRunPageState.onPressed` into a top-level provider scope (root of `MaterialApp.router`).
- `RunBloc` then receives its dependencies via `BlocProvider` factory rather than reaching into Flutter framework calls inside a button handler.
- Should make widget tests for `NewRunPage` viable for the first time.

## Out of scope

- New features, surfaces, or flows.
- Schema or evaluator changes.

## Dependencies / when to start

- No hard ordering. Both items are independent of Plans 4, 5, 6.
- The DI refactor becomes more valuable once Plan 4 lands (more pages will want shared repositories), so consider scheduling Plan 7 after Plan 4 to avoid touching the same wiring twice.
- The weights editor pays off most after Plan 5 (more tasks → weight tuning matters more) and Plan 6 (charts make weight changes legible).

## Notes for the future spec

- `SettingsRepository.getEvaluatorWeights` and `setEvaluatorWeights` already exist (Plan 3, Task 5). The editor is purely UI.
- Default weights are exported from `lib/core/scoring.dart` as `defaultEvaluatorWeights`. The editor must show "Default" vs "Override" state per row.
- The DI refactor is a small mechanical change but touches `app.dart`, `main.dart`, `new_run_page.dart`, and possibly `run_progress_page.dart`. Worth doing in one commit, with no behavioral changes.

## See also

- `docs/plans/2026-05-02-evaluators-and-scoring.md` — defines `defaultEvaluatorWeights` and the settings keys.
- `docs/plans/2026-05-02-foundation-and-first-slice.md` — Task 17 (NewRunPage) explicitly notes "Plan 4 will refactor this with proper provider DI."
