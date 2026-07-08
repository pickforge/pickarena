# PickArena tasks

This directory holds file-backed benchmark tasks for PickArena. Start here when adding or reviewing task bundles.

## Current official Flutter tasks

Official Flutter tasks live under `tasks/flutter`:

- `accessibility.quantity_stepper_semantics`
- `async.refresh_deduplicator`
- `forms.email_validation`
- `lists.contact_search`
- `navigation.auth_redirect_race`
- `persistence.offline_feed_preferences`
- `platform.channel_mock`
- `refactor.price_label_formatter`
- `state.selection_controller`
- `ui.action_bar_overflow`

Each task is admitted only when its QA evidence is present and current.

## Bundle shape

Every task bundle should keep this shape:

```txt
task.yaml
instruction.md
baseline/
hidden_tests/
solution/
negative_cases/
qa/admission_report.json
```

- `task.yaml` declares metadata, workspace files, hidden verifiers, reference files, negative cases, resources, and release status.
- `instruction.md` is the human-style prompt shown to the agent.
- `baseline/` is the starting workspace copied into the agent run.
- `hidden_tests/` stays out of prompts and workspaces until grading.
- `solution/` is the reference passing implementation used by QA.
- `negative_cases/` contains known-bad fixes that must fail.
- `qa/admission_report.json` records admission evidence.

## Authoring flow

1. Read the active benchmark spec: [`docs/specs/2026-06-15-pickarena-mobile-agent-benchmark.md`](../docs/specs/2026-06-15-pickarena-mobile-agent-benchmark.md).
2. Use the practical guide: [`tasks/AUTHORING.md`](AUTHORING.md).
3. Start with the promotion ladder: idea -> task card -> draft bundle -> QA candidate -> admitted -> active -> retired.
4. Write the prompt before hidden tests.
5. Keep hidden assets, solutions, and author notes out of the baseline workspace.
6. Add negative cases for noop, API-breaking, and overfit fixes.
7. Run task QA and commit the admission report only after reviewing it.

## Commands

Run QA for one current Flutter task:

```sh
cd app
dart run --verbosity=error dart_arena:dart_arena_task_qa \
  --out build/task_qa \
  --task-bundle-root ../tasks/flutter \
  --task forms.email_validation
```

Run QA for all current Flutter tasks:

```sh
cd app
dart run --verbosity=error dart_arena:dart_arena_task_qa \
  --out build/task_qa \
  --task-bundle-root ../tasks/flutter
```

Review generated reports before copying admission evidence into task folders.

## Quick checklist

- [ ] Prompt is realistic and bounded.
- [ ] Baseline fails the intended hidden behavior.
- [ ] Reference solution passes public and hidden checks.
- [ ] Hidden tests cover behavior, not implementation trivia.
- [ ] Negative cases are rejected.
- [ ] QA report exists under `qa/admission_report.json`.
- [ ] Task metadata is stable and release status is intentional.
