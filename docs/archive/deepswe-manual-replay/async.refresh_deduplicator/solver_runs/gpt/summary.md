# GPT solver summary

## Status

Fresh DeepSWE solver rerun with public-only workspace snapshot, durable patch, clean replay, session transcript, and telemetry captured.

Not a full DeepSWE completion claim; provider-internal stream chunks, broader performance sampling, clean committed provenance, and authored-by provenance remain pending.

## Model

`openai-codex/gpt-5.5:xhigh`

## Solver inputs

- instruction
- pubspec
- controller source
- public test only
- no restricted assets reported or found in the captured workspace snapshot

## Patch artifacts

- patch: `rerun_2026_06_19/solver.patch`
- replay result: `rerun_2026_06_19/rerun_result.json`
- pre-hidden workspace snapshot: `rerun_2026_06_19/workspace_snapshot/`

## Validation evidence

- public replay: 2/2 passed from `rerun_2026_06_19/public_results.log`
- hidden replay after injection: 6/6 passed from `rerun_2026_06_19/hidden_results.log`
- 10-run hidden loop: 10/10 passed from `flake_runs_10/gpt_fresh_rerun_summary.json`

## Trajectory and telemetry artifacts

- subagent prompt: `rerun_2026_06_19/trajectory/subagent_input.md`
- subagent output: `rerun_2026_06_19/trajectory/subagent_output.md`
- subagent metadata: `rerun_2026_06_19/trajectory/subagent_meta.json`
- subagent session transcript: `rerun_2026_06_19/trajectory/subagent_session.jsonl`
- duration: `152440` ms
- usage: input `25051`, output `6724`, cache read `42496`, cost `0.348223`, turns `7`, tool count `10`

## Caveats

- provider-internal stream chunks beyond the subagent session JSONL are not exported
- broader performance sampling remains pending
- clean committed provenance remains pending
