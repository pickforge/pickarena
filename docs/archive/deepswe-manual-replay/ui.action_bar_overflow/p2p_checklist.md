# P2P checklist

## Status

Public pass-to-pass behavior is preserved by the fresh repaired reruns. GPT, MiniMax, and Kimi are promoted; GLM remains failed on hidden replay; Opus was unavailable.

## Public behavior preservation

| Public behavior | Evidence |
| --- | --- |
| Wide bar renders primary and secondary actions inline. | Public replay passed for all four active fresh reruns. |
| Compact bar keeps the primary action direct and exposes secondary actions through overflow. | Public replay passed for all four active fresh reruns. |
| Public API keys and constructors remain source-compatible. | Public tests compile and pass for all four active fresh reruns. |

## Evidence

- Full task QA repetition: `qa_repetition/qa_repetition_result.json`
- Public replay logs: `solver_runs/{gpt,glm,minimax,kimi}/rerun_2026_06_19/public_results.log`
- Fresh replay results: `solver_runs/{gpt,glm,minimax,kimi}/rerun_2026_06_19/rerun_result.json`

## Result

P2P preservation is accepted for the repaired public contract.
