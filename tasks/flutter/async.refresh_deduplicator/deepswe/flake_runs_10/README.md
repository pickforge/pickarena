# Restricted evaluator-only logs

This directory contains a 10-run hidden-verifier loop for DeepSWE hardening.

The `*_run_*.log` files are restricted evaluator evidence. They may include hidden test paths, names, and assertion output. Do not expose them to solvers or treat them as solver-facing leakage-clean artifacts.

Use `flake_loop_10_result.json` and the `*_summary.json` files for high-level pass/fail reporting.
