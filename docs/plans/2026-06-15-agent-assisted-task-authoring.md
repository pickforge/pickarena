# Agent-assisted task authoring loop

Status: active note
Created: 2026-06-15

## Goal

Use multiple agents to help create stronger PickArena benchmark tasks, while keeping humans responsible for the final prompt, verifier, and admission decision.

This is for task authoring and QA. It is not a replacement for human review.

## Why this is worth doing

Dispatching 2–5 agents with different models can expose things one author misses:

- ambiguous task wording
- missing hidden edge cases
- fake-fix paths
- verifier false positives
- verifier false negatives
- flake-prone checks
- difficulty calibration problems
- mobile-framework-specific assumptions

The value is highest for V1 and V2/DeepSWE-grade tasks. For MVP, use it selectively on important or risky tasks.

## Recommended workflow

1. **Human writes the rough task idea**
   - Keep it realistic: a bug report, feature request, refactor request, or mobile dev goal.
   - Do not start with a machine-style checklist.

2. **Dispatch authoring agents**
   - Use the first N models in this fixed order: GPT 5.5 Xhigh, Opus 4.8 Xhigh, GLM 5.2 (Ollama) Xhigh, Kimi K2.7 Code (Ollama) Xhigh, MiniMax M3 (Ollama) Xhigh.
   - Use 2 for routine V1 Flutter expansion, 3 for risky or novel V1 tasks, and 5 for V2, DeepSWE-grade, security, or cross-framework tasks.
   - Ask each agent for task shape, likely implementation surface, hidden behaviors, and edge cases.
   - Keep outputs as private authoring material for official tasks.

3. **Dispatch verifier-focused agents**
   - Ask for hidden tests, f2p/p2p checks, negative cases, and fake-fix paths.
   - Require behavior-based checks, not reference-shape checks.

4. **Create the task bundle manually**
   - Human writes final `instruction.md` in a natural developer voice.
   - Put precision in hidden verifiers, not in an over-specified prompt.
   - Add baseline, hidden tests, reference solution, negative cases, and metadata.

5. **Dispatch fresh solver agents**
   - Use agents that did not help author the task.
   - Passing agents reveal if the task is solvable.
   - Failing agents reveal ambiguity, missing public context, or verifier brittleness.

6. **Run admission QA**
   - Baseline fails intended hidden behavior.
   - Reference passes public and hidden checks.
   - Noop, API-breaking, and overfit negative cases fail.
   - Hidden checks pass repeated flake runs.
   - Prompt-verifier bijection is reviewed.

7. **Admit only after human review**
   - Review prompt, verifier, reference, negative cases, and solver trajectories.
   - Mark the task active only when the evidence is clean.

## Agent roles

| Role | What it should produce |
| --- | --- |
| Ideation agent | Realistic mobile task ideas, likely app surfaces, edge cases. |
| Framework expert | Flutter/RN/Android/iOS-specific verifier and tooling advice. |
| Security reviewer | OWASP MASVS-style risks, privacy/storage/auth/deeplink/WebView checks. |
| Verifier critic | Hidden tests, f2p/p2p, negative cases, fake-fix paths. |
| Solver agent | Independent attempt that reveals ambiguity or verifier weakness. |

## Rules

- Final prompts stay human-written.
- Do not merge every agent suggestion into `instruction.md`.
- Do not let one model write the prompt, solution, and verifier alone.
- Do not admit a task just because one agent solved it.
- Do not expose official task drafts or authoring transcripts publicly.
- Fresh solver agents must not be the same agents that authored the task.
- LLM feedback is advisory; objective QA and human review decide admission.

## Track checklist

- [x] Add this workflow to the task authoring docs: `tasks/AUTHORING.md` candidate promotion ladder and agent-count guidance.
- [x] Create a reusable task card template: `tasks/AUTHORING.md` task card template.
- [ ] Define where private authoring transcripts are stored, if anywhere.
- [ ] Add a task-admission field or report section for solver-agent attempts.
- [ ] Add a lightweight rubric for deciding whether a task is too easy, too vague, or too brittle.
- [ ] Use the loop on at least one new Flutter task before expanding to React Native Android.
- [ ] Revisit after 5 tasks and decide whether it should be mandatory for V1/V2 tasks.
