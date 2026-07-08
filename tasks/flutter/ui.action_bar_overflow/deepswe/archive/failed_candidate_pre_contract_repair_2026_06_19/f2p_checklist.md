# F2P checklist

## Classification

Restricted evaluator-only artifact. This checklist summarizes hidden-verifier failure-to-pass coverage and must not be provided to solvers.

## Status

Baseline failure is verified by admission QA and by the 10-run hidden loop. All five fresh solvers also failed hidden replay, so this slice has no promoted F2P solver evidence yet.

## Failure-to-pass requirements

| Requirement | Baseline result | Fresh solver evidence |
| --- | --- | --- |
| Wide layouts omit overflow when all secondary actions fit. | Baseline fails hidden verifier. | Reference passes; all fresh solvers failed hidden. |
| Priority/tie ordering remains stable in partial splits. | Baseline fails hidden verifier. | Reference passes; all fresh solvers failed hidden. |
| Resize/rebuild does not duplicate or lose actions. | Baseline fails hidden verifier. | Reference passes; all fresh solvers failed hidden. |
| Overflow/inline controls remain semantically usable. | Baseline fails hidden verifier. | Reference passes; all fresh solvers failed hidden. |

## Evidence

- Admission report: `qa/admission_report.json`
- 10-run hidden loop: `flake_runs_10/flake_loop_10_result.json`
- Failed fresh replay: `replay_manifest.json`

## Remaining nuance

This proves the current slice is hard for fresh solvers, not that it is DeepSWE-ready. Promotion still requires at least three fresh solver families with clean public+hidden replay.
