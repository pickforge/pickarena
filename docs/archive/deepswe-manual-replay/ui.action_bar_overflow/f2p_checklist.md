# F2P checklist

## Classification

Restricted evaluator-only artifact. Do not provide this checklist to solvers.

## Status

The repaired contract has three clean replay-verified promoted solver families: GPT, MiniMax, and Kimi. GLM remains the failed fresh solver family. Baseline and reference expectations are stable in the 10-run loop.

## Evidence

- Fresh replay manifest: `replay_manifest.json`
- 10-run loop: `flake_runs_10/flake_loop_10_result.json`
- QA repetition: `qa_repetition/qa_repetition_result.json`

## Remaining nuance

DeepSWE is still incomplete because provenance, provider stream chunks, and workspace-isolation evidence remain unavailable or partial.
