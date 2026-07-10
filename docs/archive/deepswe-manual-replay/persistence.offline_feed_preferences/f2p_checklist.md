# F2P checklist

## Classification

Restricted evaluator-only artifact. This checklist summarizes hidden-verifier failure-to-pass coverage and must not be provided to solvers.

## Status

Baseline failure is verified by admission QA and by the 10-run hidden loop.

## Failure-to-pass requirements

| Requirement | Baseline result | Passing evidence |
| --- | --- | --- |
| Latest save persists across fresh repository instances. | Baseline fails hidden verifier. | Reference, GPT, MiniMax, GLM, and Kimi pass hidden replay and 10-run loop. |
| Corrupt or unknown stored fields default only the bad field. | Baseline fails hidden verifier. | Reference and all four fresh solvers pass hidden replay. |
| Valid seeded store values still load. | Baseline fails hidden verifier. | Reference and all four fresh solvers pass hidden replay. |
| Repositories remain isolated by injected stores. | Baseline fails hidden verifier. | Reference and all four fresh solvers pass hidden replay. |

## Evidence

- Admission report: `qa/admission_report.json`
- 10-run hidden loop: `flake_runs_10/flake_loop_10_result.json`
- Fresh replay: `replay_manifest.json`

## Remaining nuance

This proves behavioral failure-to-pass for the accepted persistence contract. It does not prove clean committed provenance, authoring provenance, or provider-internal stream capture.
