# MiniMax solver summary

## Status

Sanitized solver attempt summary with durable patch and clean replay evidence captured.

Not a full DeepSWE trajectory; raw provider/harness trajectory, pre-hidden-injection workspace snapshot, telemetry, and clean committed provenance remain pending.

## Model

`ollama/minimax-m3:cloud:xhigh`

## Reported solver inputs

- instruction
- pubspec
- controller source
- public test only
- no restricted assets reported

## Patch artifacts

- patch: `solver.patch`
- patch SHA-256: `4143d14f8fd76e6a5d9e8d1ad2a5286590bd3c6afd1b538607d7d4e4667a7573`
- replay result: `replay_result.json`

## Patch strategy reported

- added pending refresh future to collapse overlapping `refresh()` calls
- used latest request id guard
- `forceRefresh()` starts a new load
- stale success/error dropped
- `retry()` no-op unless current state is error

## Validation evidence

- `flutter pub get` succeeded per transient solver report
- public test file passed 2/2
- hidden after injection: 6/6 passed per `qa/v1plus_report.md`
- clean replay public: 2/2 passed from `public_results.log`
- clean replay hidden: 6/6 passed from `hidden_results.log`

## Trajectory and telemetry artifacts

- subagent prompt: `trajectory/subagent_input.md`
- subagent output: `trajectory/subagent_output.md`
- subagent metadata: `trajectory/subagent_meta.json`
- duration: `652764` ms
- usage: input `0`, output `16615`, turns `15`, tool count `14`

## Caveats

- no raw provider/harness trajectory
- no pre-hidden-injection raw solver workspace snapshot
- subagent-level duration/usage metadata is captured; full provider stream/tool transcript and verified billing cost remain pending
- exact overlap `isLoading` behavior is covered only to the current verifier depth; stronger DeepSWE overlap flake/telemetry remains pending.
