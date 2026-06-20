# Leakage audit

## Scope

Solver-facing scan covers patches, sanitized summaries, public replay logs, pre-hidden workspace snapshots, subagent prompt/output/meta artifacts, redacted command telemetry summaries, flake-loop summaries, flake-loop README, QA repetition summaries, QA repetition run logs, and `p2p_checklist.md`.

## Restricted artifacts

Hidden replay logs, hidden-side dependency logs, and hidden-case mapping docs are excluded from solver-facing evidence. Canonical evaluator fixtures outside this `deepswe/` directory, including the hidden verifier source, reference implementation, and adversarial QA fixtures, are also evaluator-only by task policy. See `leakage_scan_result.json` for the unified DeepSWE artifact restricted glob list.

## Result

See `leakage_scan_result.json`. The scan does not include restricted evaluator-only artifacts because those intentionally contain hidden verifier details or hidden-side execution context.
