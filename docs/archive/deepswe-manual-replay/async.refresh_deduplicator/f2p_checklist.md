# F2P checklist

## Classification

Restricted evaluator-only artifact. This checklist summarizes hidden-verifier failure-to-pass coverage and must not be provided to solvers.

## Status

Baseline failure is verified by admission QA and by the 5-run and 10-run hidden loops.

## Failure-to-pass requirements

| Requirement | Baseline result | Passing evidence |
| --- | --- | --- |
| Duplicate `refresh()` calls collapse to one repository call. | Baseline fails hidden verifier. | Reference, Kimi, MiniMax, and GPT pass hidden replay; fresh solver patches pass the 10-run loop. |
| `forceRefresh()` starts a newer request while an older request is pending. | Baseline fails hidden verifier. | Reference and three fresh solver reruns pass hidden replay. |
| Stale older success cannot overwrite newer success. | Baseline fails hidden verifier. | Reference and three fresh solver reruns pass hidden replay. |
| Stale older error cannot overwrite newer success. | Baseline fails hidden verifier. | Reference and three fresh solver reruns pass hidden replay. |
| `retry()` only runs from error and can recover to success. | Baseline lacks complete guarded retry semantics. | Public error→retry test and hidden replay pass for reference and three fresh solver reruns. |
| `canRetry` is true only in error state. | Baseline fails hidden verifier. | Reference and three fresh solver reruns pass hidden replay. |

## Evidence

- Admission report: `qa/admission_report.json`
- 5-run hidden loop: `flake_runs/flake_loop_result.json`
- 10-run hidden loop: `flake_runs_10/flake_loop_10_result.json`
- Fresh rerun replay: `replay_manifest.json`

## Remaining nuance

The checker proves behavioral failure-to-pass for the accepted async contract. It does not prove provider-internal stream provenance or clean committed repository provenance.
