# Plan 5 (roadmap stub) — Benchmark Content: 9 New Tasks

> **Status:** Roadmap stub. Not yet specced. Brainstorm + write the full plan doc when ready to start.

## Goal

Expand the benchmark suite from 1 task to 10 by adding 9 new `BenchmarkTask` implementations across the 5 existing categories. Each task ships with: fixtures (broken Dart code + failing tests where applicable), prompt, judge rubric, and a configured set of evaluators via `evaluatorsFor(EvaluatorConfig)`.

## Scope

The 9 tasks (as outlined in Plan 1 and Plan 3 closing notes):

- **UI from spec:** `ui.profile_card`, `ui.expandable_list_tile`
- **State management:** `state.counter_bloc`, `state.shopping_cart_bloc`
- **Bug fix:** `bug.async_race_condition`
- **Refactor:** `refactor.god_widget`, `refactor.callback_hell`
- **Widget testing:** `test.todo_input`, `test.form_validation`

Each task lives in `lib/tasks/<category>/<task>.dart` plus a `lib/tasks/<category>/fixtures/<task>/` asset tree (pubspec, broken source, failing tests). Each one is registered via `TaskRegistry.register(...)` at app startup.

## Out of scope

- UI changes (multi-task selection, run history, etc. — those land in Plan 4)
- New evaluators (the 6 from Plan 3 are sufficient)
- New providers

## Dependencies / when to start

- No hard dependency on Plan 4. These tasks plug into the existing registry and run through the existing `RunBloc` end-to-end. Could even be developed in parallel with Plan 4.
- Tasks that target widget tests will exercise `WidgetTreeEvaluator` (already implemented in Plan 3) for the first time in real conditions.

## Notes for the future spec

- Each task is independent — order them by perceived difficulty (start with `state.counter_bloc` as a low-risk shape baseline).
- Decide whether each task uses `judgeRubric` or relies purely on objective evaluators (compile/test/widget_tree). Refactor tasks especially benefit from the LLM judge dimension.
- Per-task evaluator selection via `evaluatorsFor(config)` lets you mix and match. Some tasks may skip `widget_tree` (non-Flutter), others may skip `test` (refactor with no new behavior).
- Manual smoke for each task: pick a strong model (e.g. Claude Sonnet 4.5 or DeepSeek), run it once, sanity-check the score doesn't violate physics.

## See also

- `docs/plans/2026-05-02-foundation-and-first-slice.md` — `OffByOnePaginationTask` is the reference implementation for shape.
- `docs/plans/2026-05-02-evaluators-and-scoring.md` — defines the 6 evaluators these tasks compose.
