# Prompt/verifier bijection

## Classification

Restricted evaluator-only artifact. This file names hidden verifier cases and must not be provided to solvers.

## Status

Bijection evidence is current for the offline preferences DeepSWE slice. Four fresh solver families pass clean replay. Full DeepSWE completion remains pending on provider-internal stream chunks, clean committed provenance, authored-by provenance, and stronger workspace isolation proof.

## Sources

- `instruction.md`
- `baseline/test/offline_feed_preferences_test.dart`
- source hidden verifier: `hidden_tests/test/_hidden/offline_feed_preferences_hidden_test.dart`
- grading injection path: `test/_hidden/offline_feed_preferences_hidden_test.dart`
- `qa/admission_report.json`
- `qa/v1plus_report.md`
- `replay_manifest.json`
- `flake_report.json`

## Requirement to verifier mapping

| Requirement | Public coverage | Hidden coverage | Evidence status |
| --- | --- | --- | --- |
| Preserve public API for enums, value object, store, repository, field, and keys. | Public tests compile and use value object/repository APIs. | Hidden cases instantiate fresh repositories and stores. | API-breaking negative rejected; passing solvers preserve API. |
| `save()` writes every field through injected store. | Public same-store save/load behavior. | Fresh repository, latest-save, and isolation cases. | Covered. |
| Fresh repository over same store loads saved values. | Public behavior covered. | Hidden latest-save case covers restart-like repository replacement. | Covered. |
| Enums persist with `.name`; booleans as exact strings. | Public seeded string load covers valid values. | Hidden seeded values and latest-save cases. | Covered. |
| Missing values default per field. | Public empty-store default test. | Hidden partial-corruption case. | Covered. |
| Unknown/malformed values never throw and only bad field defaults. | Public seeded valid strings plus negative QA. | Hidden partial-corruption case. | Covered. |
| Repositories are isolated by injected store. | Not isolated publicly. | Hidden store-isolation case. | Covered. |
| Deterministic offline implementation with no new dependencies/IO/timers/network. | QA prompt safety and patch review evidence. | Not a dedicated hidden static assertion. | Partial static coverage; no new dependency appears in patches. |

## Hidden assertion back-mapping

- `latest save wins across repository instances`
- `partial corruption defaults only the bad field`
- `valid hidden seeded values still load`
- `repositories are isolated by their injected stores`


## Evidence pointers

- Clean replay: `replay_manifest.json`
- Four passing fresh solver reruns: `solver_runs/{gpt,minimax,glm,kimi}/rerun_2026_06_19/`
- 10-run hidden flake loop: `flake_runs_10/flake_loop_10_result.json`
- Solver-facing leakage scan: `leakage_scan_result.json`

## Known coverage nuances

- Deterministic/offline/no-new-dependency behavior is checked by QA/prompt safety and patch review, not a dedicated hidden static verifier.
- Original authored-by provenance is not durably known.
- Provider-internal stream chunks/session JSONL were not exposed.
