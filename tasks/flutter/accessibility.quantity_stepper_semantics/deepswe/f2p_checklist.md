# F2P checklist

## Classification

Restricted evaluator-only artifact. This checklist summarizes hidden-verifier failure-to-pass coverage and must not be provided to solvers.

## Status

Baseline failure is verified by admission QA and by the 10-run hidden loop. MiniMax and Kimi are retained as failed public-only solver evidence.

## Failure-to-pass requirements

| Requirement | Baseline result | Passing evidence |
| --- | --- | --- |
| Real controls expose correct decrease/increase accessibility labels. | Baseline fails hidden verifier. | Reference, GPT, GLM, and Opus pass hidden replay and 10-run loop. |
| Value node exposes label and semantic value matching visible value. | Baseline fails hidden verifier. | Reference and passing solvers pass hidden replay. |
| Boundary controls are disabled to accessibility and do not call `onChanged`. | Baseline fails hidden verifier. | Reference and passing solvers pass hidden replay. |
| Screen-reader tap invokes the real callback exactly once. | Baseline fails hidden verifier. | Reference and passing solvers pass hidden replay. |
| Accessibility strings are not added as visible labels. | Baseline fails hidden verifier. | Reference and passing solvers pass hidden replay. |

## Evidence

- Admission report: `qa/admission_report.json`
- 10-run hidden loop: `flake_runs_10/flake_loop_10_result.json`
- Fresh replay: `replay_manifest.json`

## Remaining nuance

This proves behavioral failure-to-pass for the accepted accessibility contract. It does not prove clean committed provenance, authoring provenance, or provider-internal stream capture.
