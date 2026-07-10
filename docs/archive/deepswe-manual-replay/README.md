# Archived: manual DeepSWE replay artifacts

These per-task directories (`README.md`, `replay_log.md`, `replay_manifest.json`,
`solver_runs/`, `flake_report.json`, `leakage_audit.md`, telemetry, etc.) were the
hand-run replay/QA evidence produced while building the benchmark's grading path.

They are superseded by runner behaviour: the orchestrator now replays the captured
patch into a fresh clean baseline as the official grading path, and the release gate
verifies fresh execution (see #6). Kept here for provenance; not read by any code and
not part of the task-bundle digest.
