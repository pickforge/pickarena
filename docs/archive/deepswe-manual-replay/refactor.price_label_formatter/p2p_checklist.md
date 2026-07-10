# P2P checklist

## Status

Public pass-to-pass behavior is preserved for the reference solution and three promoted fresh solver reruns: GPT, MiniMax, and GLM.

## Public behavior preservation

| Public behavior | Evidence |
| --- | --- |
| Formatter keeps the original visible default formatting for plain prices. | Public formatter test and public replay pass. |
| Product tile shows regular, sale, and free price labels with the same visible text. | Public product tile tests pass in replay and QA repetition. |
| Cart line row shows name, quantity, unit price, and line total. | Public cart row test passes in replay and QA repetition. |
| Checkout summary shows subtotal, shipping, and total. | Public checkout summary test passes in replay and QA repetition. |
| Public APIs remain source-compatible for consumers. | Public tests compile; API-breaking negative remains rejected by QA. |

## Evidence

- Full task QA repetition: `qa_repetition/qa_repetition_result.json`
- Public replay logs: `solver_runs/{gpt,minimax,glm}/rerun_2026_06_19/public_results.log`
- Fresh replay results: `solver_runs/{gpt,minimax,glm}/rerun_2026_06_19/rerun_result.json`
- Original V1 admission report: `qa/admission_report.json`

## Result

P2P preservation is accepted for this slice. Clean committed provenance remains outside this checklist.
