# Kimi solver summary

## Status

Sanitized solver attempt summary with durable patch and clean replay evidence captured.

Not a full DeepSWE trajectory; raw provider/harness trajectory, pre-hidden-injection workspace snapshot, telemetry, and clean committed provenance remain pending.

## Model

`ollama/kimi-k2.7-code:cloud:xhigh`

## Reported solver inputs

- instruction
- pubspec
- controller source
- public test only
- no restricted assets reported

## Patch artifacts

- patch: `solver.patch`
- patch SHA-256: `e95cc2e18db193d0bb821430229ecffc9a41724421587b52aaed674b0013f88d`
- replay result: `replay_result.json`

## Patch strategy reported

- replaced single in-flight boolean with in-flight count
- used request ids / latest request guard
- deduplicated `refresh()`
- allowed `forceRefresh()` to start a newer load
- ignored stale success/error updates
- `retry()` only from error

## Validation evidence

- public: `flutter test`, 2/2 passed per transient solver report
- hidden after injection: 6/6 passed per `qa/v1plus_report.md`
- clean replay public: 2/2 passed from `public_results.log`
- clean replay hidden: 6/6 passed from `hidden_results.log`

## Trajectory and telemetry artifacts

- subagent prompt: `trajectory/subagent_input.md`
- subagent output: `trajectory/subagent_output.md`
- subagent metadata: `trajectory/subagent_meta.json`
- duration: `42691` ms
- usage: input `42252`, output `4227`, turns `5`, tool count `7`

## Caveats

- no raw provider/harness trajectory
- no pre-hidden-injection raw solver workspace snapshot
- subagent-level duration/usage metadata is captured; full provider stream/tool transcript and verified billing cost remain pending
- report noted duplicate `refresh()` returned immediately rather than necessarily awaiting active request; current verifier accepted this but do not treat it as stronger than current coverage.
