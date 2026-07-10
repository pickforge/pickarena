# Prompt/verifier bijection

## Classification

Restricted evaluator-only artifact. This file names hidden verifier cases and must not be provided to solvers.

## Status

Bijection evidence is current for the quantity-stepper accessibility DeepSWE slice. Three fresh solver families pass clean replay; two public-passing solvers fail hidden replay and are retained as failed-solver evidence. Full DeepSWE completion remains pending on provider-internal stream chunks, clean committed provenance, authored-by provenance, and stronger workspace isolation proof.

## Sources

- `instruction.md`
- `baseline/test/quantity_stepper_test.dart`
- source hidden verifier: `hidden_tests/test/_hidden/quantity_stepper_semantics_hidden_test.dart`
- grading injection path: `test/_hidden/quantity_stepper_semantics_hidden_test.dart`
- `qa/admission_report.json`
- `qa/v1plus_report.md`
- `replay_manifest.json`
- `flake_report.json`

## Requirement to verifier mapping

| Requirement | Public coverage | Hidden coverage | Evidence status |
| --- | --- | --- | --- |
| Preserve widget API, static keys, visible compact row, and icons. | Public widget tests cover keys, visible text, and tap behavior. | Hidden cases check semantics without visible label regressions. | API-breaking and visible-label negatives rejected. |
| Decrease control announces `Decrease quantity`. | Not public-covered. | Hidden decrement semantics case. | Covered. |
| Increase control announces `Increase quantity`. | Not public-covered. | Hidden increment semantics case. | Covered. |
| Current value announces label `Quantity` and numeric semantic value. | Public visible value test. | Hidden value semantics cases. | Covered. |
| Boundary controls disabled to accessibility and inert. | Public visual boundary taps are inert. | Hidden accessibility disabled cases. | Covered. |
| Enabled visual taps and screen-reader taps call `onChanged(value ± 1)` exactly once. | Public visual taps call once. | Hidden screen-reader tap case. | Covered. |
| Behavior holds for non-public/special-case ranges. | Public covers representative min/max. | Hidden special-range case. | Covered. |
| Accessibility strings are not added as visible text. | Public visible row tests plus hidden no-visible-label case. | Hidden no-visible-label case. | Covered. |

## Hidden assertion back-mapping

- `mid-range decrement control announces Decrease quantity`
- `mid-range increment control announces Increase quantity`
- `current value node exposes Quantity label and numeric value`
- `at min the decrement control is disabled to accessibility`
- `at max the increment control is disabled to accessibility`
- `screen-reader tap invokes the real onChanged exactly once`
- `value semantics stay consistent with visible text on rebuild`
- `special-case ranges still expose accessible controls`
- `accessibility strings are not added as visible label text`


## Evidence pointers

- Clean replay: `replay_manifest.json`
- Three passing fresh solver reruns: `solver_runs/{gpt,glm,opus}/rerun_2026_06_19/`
- Failed public-only solvers: `solver_runs/{minimax,kimi}/rerun_2026_06_19/`
- 10-run hidden flake loop: `flake_runs_10/flake_loop_10_result.json`
- Solver-facing leakage scan: `leakage_scan_result.json`

## Known coverage nuances

- MiniMax and Kimi demonstrate that public pass is insufficient for semantic correctness.
- Original authored-by provenance is not durably known.
- Provider-internal stream chunks/session JSONL were not exposed.
