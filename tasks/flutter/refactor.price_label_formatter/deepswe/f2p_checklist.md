# F2P checklist

## Classification

Restricted evaluator-only artifact. This checklist summarizes hidden-verifier failure-to-pass coverage and must not be provided to solvers.

## Status

Baseline failure is verified by admission QA and by the 10-run hidden loop. Kimi is retained as a failed public-only solver and demonstrates that public pass is not enough.

## Failure-to-pass requirements

| Requirement | Baseline result | Passing evidence |
| --- | --- | --- |
| Complete robust cents formatting including zero, sub-dollar, whole-dollar, non-whole, and grouped thousands. | Baseline fails hidden verifier. | Reference, GPT, MiniMax, and GLM pass hidden replay and 10-run loop. |
| Sale labels show compare-at only when strictly greater. | Baseline fails hidden verifier. | Reference and passing solvers cover higher/equal/lower/null/free compare-at behavior. |
| Product tile uses injected formatter for regular and sale prices. | Baseline fails hidden verifier. | Reference, GPT, MiniMax, and GLM pass routing checks. |
| Cart line row uses injected formatter for unit and line total. | Baseline fails hidden verifier. | Reference, GPT, MiniMax, and GLM pass routing checks. |
| Checkout summary uses injected formatter for subtotal, shipping, and total. | Baseline fails hidden verifier. | Reference, GPT, MiniMax, and GLM pass routing checks. |

## Evidence

- Admission report: `qa/admission_report.json`
- 10-run hidden loop: `flake_runs_10/flake_loop_10_result.json`
- Fresh replay: `replay_manifest.json`

## Remaining nuance

This proves behavioral failure-to-pass for the accepted refactor contract. It does not prove clean committed provenance, authoring provenance, or provider-internal stream capture.
