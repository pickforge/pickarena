# Prompt/verifier bijection

## Classification

Restricted evaluator-only artifact. Do not provide this file to solvers.

## Status

After the public-contract repair, three fresh solver families replay cleanly and one active fresh solver family remains failed. Opus was unavailable and has no active solver run.

## Sources

- `instruction.md`
- `baseline/test/responsive_action_bar_test.dart`
- canonical evaluator fixtures
- `qa/admission_report.json`
- `replay_manifest.json`
- `flake_report.json`

## Requirement to verifier mapping

| Requirement area | Public coverage | Evaluator coverage | Evidence status |
| --- | --- | --- | --- |
| Preserve public API and static keys. | Public widget tests compile and pass. | Evaluator replay checks compatibility across layouts. | Covered by promoted reruns. |
| Keep the primary CTA direct and tappable. | Public wide and compact tests exercise the primary key. | Evaluator replay checks direct reachability under layout pressure. | Covered by promoted reruns. |
| Move secondary actions deterministically between inline and overflow. | Public compact/wide cases exercise overflow behavior. | Evaluator replay covers ordering, rebuild, and accessibility invariants. | Covered by promoted reruns. |
| Preserve callbacks and labels. | Public tap and key checks exercise visible controls. | Evaluator replay checks action integrity across modes. | Covered by promoted reruns. |

## Evidence pointers

- Promoted fresh solver replay: `replay_manifest.json`
- Active fresh solver reruns: `solver_runs/{gpt,glm,minimax,kimi}/rerun_2026_06_19/`
- 10-run loop: `flake_runs_10/flake_loop_10_result.json`
- Solver-facing leakage scan: `leakage_scan_result.json`
