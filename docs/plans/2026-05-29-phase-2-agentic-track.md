# Phase 2 — Agentic Flutter Dev Track Implementation Plan

> **Status:** Draft plan.
> **Parent spec:** `docs/specs/2026-05-29-flutter-benchmark-v2-design.md`
> **Dependency:** Phase 1 hidden verifier support.

## Goal

Add a patch-based benchmark mode where agents can inspect a workspace, edit multiple files, run commands, iterate, and submit a final patch that is graded by hidden behavioral verifiers.

## Success criteria

- A benchmark task can run in `agentic` mode.
- The runner prepares a clean workspace for each model/task/trial.
- An agent harness can operate inside that workspace.
- The final workspace diff is captured and persisted.
- Hidden verifiers grade the final patch.
- Existing codegen tasks still run unchanged.

## Current code anchors

- `ProviderMode.agent` already exists, but `DroidExecProvider.generate` intentionally disables tools and answers from the prompt. Do not reuse it as the tool-enabled agent harness.
- `RunBloc._runCombo` currently assumes every run produces one extracted Dart file. Agentic execution needs a separate orchestrator path.
- `WorkdirManager.createTaskWorkdir` currently writes a file map and optional generated code. Agentic tasks need workspace-copy support and must exclude hidden verifier/reference files.
- `TaskRunResult` and Drift `TaskRuns` currently have no patch, track, harness, or trajectory fields.

## Architecture

Add an agentic pipeline beside the existing codegen pipeline:

```text
Codegen:
  prompt -> response -> extracted file -> evaluators

Agentic:
  workspace -> agent harness -> final diff -> hidden/public/regression evaluators
```

The two tracks should share:

- task registry;
- evaluator result model;
- run persistence;
- leaderboard filters;
- task-run details.

They should not share the assumption that one generated Dart block replaces one file.

Keep `ModelProvider` for raw/codegen model calls and introduce `AgentHarness` for tool-enabled workspace execution. A harness may internally call `droid exec`, but it must accept a working directory and must not prepend the current no-tools direct-answer prompt.

## File structure

Likely files to create:

- `lib/agent/agent_harness.dart`
- `lib/agent/agent_run_result.dart`
- `lib/agent/droid_agent_harness.dart`
- `lib/runner/agentic_run_orchestrator.dart`
- `lib/core/task_workspace.dart`
- `lib/core/patch_capture.dart`
- `test/agent/agent_harness_test.dart`
- `test/runner/agentic_run_orchestrator_test.dart`
- `test/core/patch_capture_test.dart`

Likely files to modify:

- `lib/core/benchmark_task.dart`
- `lib/providers/model_provider.dart`
- `lib/providers/droid_exec_provider.dart` or add a separate Droid agent provider
- `lib/runner/run_bloc.dart`
- `lib/runner/workdir_manager.dart`
- `lib/storage/database.dart`
- `lib/ui/pages/new_run_page.dart`
- `lib/ui/pages/task_run_details_page.dart`

## Task 1: Add track-aware task execution

- [ ] Add `BenchmarkTrack.codegen` and `BenchmarkTrack.agentic`.
- [ ] Branch `RunBloc` execution by task track or selected run mode.
- [ ] Keep codegen behavior identical for current tasks.
- [ ] Add tests proving mixed codegen/agentic task lists route correctly.
- [ ] Keep run-mode selection separate from `ProviderMode`; provider mode describes the model source, while run mode describes benchmark execution semantics.
- [ ] Fail fast with a clear error if an agentic task is selected without an agent harness.

## Task 2: Add workspace preparation for agentic tasks

- [ ] Support copying an entire workspace, not just selected fixture files.
- [ ] Initialize a local git repository in the workdir for diff capture.
- [ ] Commit baseline workspace before agent execution.
- [ ] Ensure hidden tests/reference solutions are excluded from the agent workspace.
- [ ] Add workspace cleanup and path sanitization tests.

Implementation details:

- Add a `TaskWorkspace` model with visible files or a fixture root, instruction text, and required setup command metadata.
- Reject workspace file paths that are absolute or escape the workdir with `..`.
- Run `git init`, configure local-only user metadata if required by git, `git add .`, and commit the visible baseline before invoking the harness.
- Do not copy `.git`, hidden verifier folders, reference folders, author notes, or task QA reports into the agent workspace.

## Task 3: Define `AgentHarness`

Add a provider-neutral interface:

```dart
abstract class AgentHarness {
  String get id;

  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
  });
}
```

`AgentRunResult` should include:

- stdout/stderr previews;
- exit code;
- latency;
- prompt/completion tokens when available;
- trajectory/log path when available;
- final status.
- timeout/cancellation status;
- harness-specific metadata that is safe to persist.

Keep stdout/stderr previews bounded, following the existing `RunBloc._maxPreviewChars` pattern.

## Task 4: Add initial standardized harness

- [ ] Implement one local harness first, preferably Factory Droid with tools enabled.
- [ ] Run the agent with `workingDirectory` set to the benchmark workspace.
- [ ] Pass a strict instruction that final output should not include hidden tests or external assumptions.
- [ ] Capture stdout/stderr and command metadata.
- [ ] Keep the current no-tools `DroidExecProvider` available for codegen mode.
- [ ] Implement this as a new `DroidAgentHarness`, not by changing `DroidExecProvider.generate`.
- [ ] Pass only the visible task instruction and visible workspace context; never pass hidden verifier names, paths, or reference notes.
- [ ] Enforce timeout and kill the process tree or child process when timeout fires.
- [ ] Treat non-zero harness exit as a harness failure but still attempt patch capture and evaluator execution when a workspace exists.

## Task 5: Capture and persist final patch

- [ ] Add `PatchCapture` using git diff from the baseline commit.
- [ ] Store patch text or a path to patch artifact.
- [ ] Show patch in task-run details.
- [ ] Add export support for patch metadata.

Patch capture should use `Process.run('git', ['diff', '--binary'], workingDirectory: workspace.path)` rather than shell strings. Also capture `git status --porcelain` for diagnostics.

Persistence additions for Phase 2:

- `benchmarkTrack` or `track`;
- `harnessId`;
- `patchArtifactPath` or bounded patch text;
- `trajectoryLogPath` when available.

If Phase 4 has not run yet, add these fields with nullable/default values and include a Drift migration plus regenerated `database.g.dart`.

## Task 6: Evaluate final workspace

- [ ] Run public tests, hidden tests, analyzer, and regression checks after the agent exits.
- [ ] Fail task if workspace has no meaningful diff and hidden tests fail.
- [ ] Keep evaluator output shape consistent with codegen mode.
- [ ] Add failure reason for harness timeout or non-zero harness exit.
- [ ] Inject hidden verifiers only after harness execution has fully ended.
- [ ] Preserve public evaluator behavior for codegen tasks by reusing existing `Evaluator` implementations.
- [ ] Add a synthetic evaluator result such as `agent_harness` to record timeout/non-zero/exception status.

## Task 7: UI support

- [ ] Add a run-mode selector: `Codegen`, `Agentic`, or `Both` if useful.
- [ ] Show agentic task-run phases: preparing workspace, running agent, capturing patch, grading.
- [ ] Show trajectory/log path and final patch in task details.
- [ ] Clearly separate raw API models from agent harnesses in leaderboard filters.
- [ ] Disable agentic mode in the UI unless at least one selected task supports `BenchmarkTrack.agentic` and at least one harness is configured.
- [ ] Update progress snapshots with agentic-specific phases without removing existing codegen phases.

## Validation

Run:

```sh
flutter analyze
flutter test
```

Targeted tests:

```sh
flutter test test/core/patch_capture_test.dart
flutter test test/runner/agentic_run_orchestrator_test.dart
flutter test test/agent/agent_harness_test.dart
```

Manual smoke:

- run one tiny agentic task with a local harness;
- confirm hidden tests are not present before agent execution;
- confirm final patch is captured;
- confirm hidden verifier runs after agent exits.

## Risks

- Native agent harnesses differ heavily; a standardized harness may under-measure some agents.
- Tool-enabled agents can be slower and more expensive.
- Capturing trajectories safely without leaking secrets requires care.
- Agent runs need stronger timeout/cancellation behavior than single-shot API calls.
- Giving an agent tools inside a workspace creates local filesystem risk; restrict working directory, avoid passing secrets, and store only bounded log previews.
- Git diff capture depends on a clean baseline commit; failed git initialization must become an environment/harness failure instead of silently grading an untracked workspace.

## Exit criteria

Phase 2 is complete when at least one agentic task can be solved through a tool-enabled harness, graded with hidden verifiers, and displayed/exported with final patch evidence.

Rollback/compatibility:

- Keep the codegen path as the default run mode and leave all existing task IDs on `BenchmarkTrack.codegen`.
- If the initial harness is unstable, disable agentic selection in the UI while retaining persisted rows and codegen functionality.
