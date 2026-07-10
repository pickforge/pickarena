# Leakage audit

## Scope

Solver-facing scan covers public logs, patches, sanitized workspace snapshots, active subagent input/output/meta trajectories, README/manifest/audit summaries, command telemetry summaries, flake-loop summaries, QA repetition summaries, and `p2p_checklist.md`.

## Exclusions

The scan excludes `archive/**`, restricted checklists, hidden replay logs, raw flake-loop logs, raw QA repetition logs, and canonical evaluator-only task directories outside `deepswe/`.

## Result

See `leakage_scan_result.json`. The solver-facing scan passed with zero findings across 87 checked files. Generic trajectory references to unavailable hidden tests/solutions/negative cases were classified as solver-facing policy text, not restricted hidden content.
