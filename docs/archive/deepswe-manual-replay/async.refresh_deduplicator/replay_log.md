# Clean replay log: async.refresh_deduplicator

This log captures clean patch replay for the existing Kimi and MiniMax solver outputs.

Solver patches were generated from the solver-modified `lib/feed_refresh_controller.dart` files and replayed into fresh baseline copies. Staging ran public tests only. Grading used a separate fresh baseline copy, applied the same patch, then injected hidden tests.

Full DeepSWE completion remains pending because full provider/tool-call telemetry, a pre-injection raw solver workspace snapshot, and a clean committed provenance run are still missing. Solver subagent prompt/output/usage metadata is captured separately in `telemetry_report.json`.

## kimi

- Patch: `solver_runs/kimi/solver.patch`
- Patch SHA-256: `e95cc2e18db193d0bb821430229ecffc9a41724421587b52aaed674b0013f88d`
- Public replay: exit `0`, log `solver_runs/kimi/public_results.log`
- Hidden replay: exit `0`, log `solver_runs/kimi/hidden_results.log`
- Result JSON: `solver_runs/kimi/replay_result.json`
- Clean replay verified: `true`

## minimax

- Patch: `solver_runs/minimax/solver.patch`
- Patch SHA-256: `4143d14f8fd76e6a5d9e8d1ad2a5286590bd3c6afd1b538607d7d4e4667a7573`
- Public replay: exit `0`, log `solver_runs/minimax/public_results.log`
- Hidden replay: exit `0`, log `solver_runs/minimax/hidden_results.log`
- Result JSON: `solver_runs/minimax/replay_result.json`
- Clean replay verified: `true`
