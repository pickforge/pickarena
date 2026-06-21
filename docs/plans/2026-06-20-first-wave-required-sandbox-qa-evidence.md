# First-wave required-sandbox Task QA evidence

Status: evidence captured; V2 clean replay completed
Created: 2026-06-20
Goal id: `10c571fa-4c4b-42d0-9432-8dc0aff6e4e7`

This is not a completion claim. `deepSWEComplete: false` remains.

## Scope

This records redacted Task QA runtime-isolation evidence for the five first-wave Flutter tasks under a required generated-code sandbox. The run root was `app/build/task_qa_runtime_isolation_first_wave_20260619_232218/`.

Tasks:

- `async.refresh_deduplicator`
- `accessibility.quantity_stepper_semantics`
- `refactor.price_label_formatter`
- `persistence.offline_feed_preferences`
- `ui.action_bar_overflow`

## Command

Executed once per task with the task-safe output suffix:

```sh
cd app && dart run --verbosity=error dart_arena:dart_arena_task_qa --out build/task_qa_runtime_isolation_first_wave_20260619_232218/<task_safe> --task-bundle-root ../tasks/flutter --task <task> --hidden-flake-runs 1 --evaluator-timeout-seconds 60 --require-generated-code-sandbox
```

## Aggregate result

- Completed/admitted under required sandbox: `taskCount 5`, `admitted 5`, `rejected 0`.
- Sandbox: required `true`, enforced `true`, backend `bubblewrap` for all 5.
- Runtime evidence: `workspaceCount 40`, `visibleFileCount 144`, `visibleBytes 270573`, `restrictedPathCount 0`, `symlinkCount 0`, `unreadableFileCount 0`, `digestLengths [64,64,64,64,64]`.
- Guards: `workdirsUnderRunsRoot true`, `rootConfined true`, `relativePathsOnly true`, `restrictedPathsAbsent true`, `symlinksFollowed false`.

## Per-task redacted result

| Task | Status | Admitted | Rejected | workspaceCount | visibleFileCount | restrictedPathCount | digestLen |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `accessibility_quantity_stepper_semantics` | completed | 1 | 0 | 8 | 24 | 0 | 64 |
| `async_refresh_deduplicator` | completed | 1 | 0 | 6 | 18 | 0 | 64 |
| `persistence_offline_feed_preferences` | completed | 1 | 0 | 8 | 24 | 0 | 64 |
| `refactor_price_label_formatter` | completed | 1 | 0 | 8 | 48 | 0 | 64 |
| `ui_action_bar_overflow` | completed | 1 | 0 | 10 | 30 | 0 | 64 |

## Remaining blockers

- This original evidence predated the clean committed replay; V2 local replay is now captured separately in [`docs/plans/2026-06-20-v2-clean-replay-report.md`](./2026-06-20-v2-clean-replay-report.md).
- This evidence is not provider-internal stream export evidence.
- This evidence is not authored-by provenance.
- This evidence is not solver/agent harness boundary proof.
- Therefore, the runtime isolation blocker remains partially open; successful solver/agent provider-in-sandbox proof remains required.

## Redaction

This document includes only command shape, run root, task ids, counts, booleans, backend label, and digest lengths. It omits hidden paths, temp paths, solver diffs/source snippets, JSONL records, file contents, and admission-report nested details.
