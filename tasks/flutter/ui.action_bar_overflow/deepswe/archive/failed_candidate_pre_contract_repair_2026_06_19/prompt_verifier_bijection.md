# Prompt/verifier bijection

## Classification

Restricted evaluator-only artifact. This file names hidden verifier cases and must not be provided to solvers.

## Status

This is a failed DeepSWE candidate slice. The canonical task remains admitted and the reference solution passes hidden replay, but all five fresh solver families passed public replay and failed hidden replay. No solver is promoted.

## Sources

- `instruction.md`
- `baseline/test/responsive_action_bar_test.dart`
- source hidden verifier: `hidden_tests/test/_hidden/action_bar_overflow_hidden_test.dart`
- grading injection path: `test/_hidden/action_bar_overflow_hidden_test.dart`
- `qa/admission_report.json`
- `qa/v1plus_report.md`
- `replay_manifest.json`
- `flake_report.json`

## Requirement to verifier mapping

| Requirement | Public coverage | Hidden coverage | Evidence status |
| --- | --- | --- | --- |
| Preserve public API and static keys. | Public key/re-layout tests compile and pass. | Hidden re-layout checks exercise action preservation. | Canonical task covered; fresh solvers failed hidden. |
| Primary CTA remains direct and tappable. | Public wide and compact tests use the primary key. | Hidden re-layout and semantics checks keep actions reachable. | Covered by reference; no promoted solvers. |
| Wide layouts keep all secondary actions inline and omit overflow. | Public wide case. | Hidden wide case. | Covered by reference; solvers failed. |
| Compact layouts expose real overflow control and entries. | Public key/overflow test. | Hidden re-layout and semantics cases. | Covered by reference; solvers failed. |
| Lower priority stays inline longer and ties preserve order. | Instruction states this; public coverage is limited. | Hidden priority/tie case. | Fresh solvers failed. |
| No duplicate inline/overflow action and no lost action after rebuild. | Public stable-key test. | Hidden resize/rebuild case. | Fresh solvers failed. |
| Ambient text scaling and accessible labels/tap actions remain usable. | Instruction states this; public coverage is limited. | Hidden semantics case. | Fresh solvers failed. |

## Hidden assertion back-mapping

- `equal priorities keep earlier input action visible first`
- `wide layout preserves inline behavior`
- `resize and rebuild do not duplicate or lose actions`
- `semantics remain usable`


## Evidence pointers

- Failed solver replay: `replay_manifest.json`
- Five failed fresh solver reruns: `solver_runs/{gpt,glm,opus,minimax,kimi}/rerun_2026_06_19/`
- 10-run hidden failed-candidate loop: `flake_runs_10/flake_loop_10_result.json`
- Solver-facing leakage scan: `leakage_scan_result.json`

## Known coverage nuances

- Public tests are insufficient to predict hidden success for this task; all five fresh public-passing solvers failed hidden replay.
- Original authored-by provenance is not durably known.
- Provider-internal stream chunks/session JSONL were not exposed.
