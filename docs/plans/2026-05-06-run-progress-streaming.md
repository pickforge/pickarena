# Run Progress Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show live benchmark progress with per-combo phases, elapsed time, streamed answer text, and streamed reasoning/thinking where providers expose it.

**Architecture:** Add an optional streaming provider API alongside the existing `generate` API. `RunBloc` consumes stream events when available and emits richer immutable progress snapshots. `RunProgressPage` renders active combo cards with collapsible Thinking and Answer panels, while completed results continue to use the existing `TaskRunResult` flow.

**Tech Stack:** Flutter, flutter_bloc, Dio, OpenAI-compatible SSE over `/v1/chat/completions`, existing Drift persistence.

---

## File Structure

- Create `lib/providers/model_stream_event.dart`: provider-neutral stream event sealed classes.
- Modify `lib/providers/model_provider.dart`: add optional streaming capability via `StreamingModelProvider`.
- Modify `lib/providers/openai_compatible_provider.dart`: implement OpenAI-compatible SSE streaming, including `delta.reasoning_content` and `delta.content`.
- Create `lib/runner/run_progress_snapshot.dart`: immutable active-combo progress model used by `RunInProgress`.
- Modify `lib/runner/run_state.dart`: replace `currentLabels` with `active: List<RunProgressSnapshot>`.
- Modify `lib/runner/run_bloc.dart`: emit phase transitions, consume provider streams when available, keep rolling previews, and preserve final `ModelResponse`.
- Modify `lib/ui/pages/run_progress_page.dart`: render progress bar, active cards, collapsible Thinking/Answer panels, phase/elapsed details, and completed result cards during execution.
- Tests:
  - `test/providers/openai_compatible_provider_test.dart`
  - `test/runner/run_bloc_test.dart`
  - `test/ui/pages/run_progress_page_test.dart` (create if absent)

## Task 1: Provider Streaming Events

**Files:**
- Create: `lib/providers/model_stream_event.dart`
- Modify: `lib/providers/model_provider.dart`

- [ ] Add `ModelStreamEvent` sealed classes:

```dart
sealed class ModelStreamEvent {
  const ModelStreamEvent();
}

class ModelStreamStarted extends ModelStreamEvent {
  const ModelStreamStarted();
}

class ModelStreamReasoningDelta extends ModelStreamEvent {
  const ModelStreamReasoningDelta(this.text);
  final String text;
}

class ModelStreamContentDelta extends ModelStreamEvent {
  const ModelStreamContentDelta(this.text);
  final String text;
}

class ModelStreamUsage extends ModelStreamEvent {
  const ModelStreamUsage({this.promptTokens, this.completionTokens});
  final int? promptTokens;
  final int? completionTokens;
}

class ModelStreamCompleted extends ModelStreamEvent {
  const ModelStreamCompleted();
}
```

- [ ] Add this interface to `model_provider.dart`:

```dart
abstract class StreamingModelProvider implements ModelProvider {
  Stream<ModelStreamEvent> generateStream({
    required String prompt,
    required String model,
    Duration? timeout,
  });
}
```

- [ ] Import `model_stream_event.dart` from `model_provider.dart` so consumers can type-check `provider is StreamingModelProvider` without importing provider-specific files.

- [ ] Run:

```sh
flutter analyze
```

Expected: no new issues beyond the existing unrelated analyzer issues.

## Task 2: OpenAI-Compatible SSE Streaming

**Files:**
- Modify: `lib/providers/openai_compatible_provider.dart`
- Test: `test/providers/openai_compatible_provider_test.dart`

- [ ] Write tests using mocked Dio `post<ResponseBody>` or `post` with `ResponseType.stream` that feed these lines:

```txt
data: {"choices":[{"delta":{"reasoning_content":"think"}}]}
data: {"choices":[{"delta":{"content":"answer"}}]}
data: {"usage":{"prompt_tokens":3,"completion_tokens":4},"choices":[{"delta":{},"finish_reason":"stop"}]}
data: [DONE]
```

Expected emitted events:

```dart
[
  isA<ModelStreamStarted>(),
  isA<ModelStreamReasoningDelta>().having((e) => e.text, 'text', 'think'),
  isA<ModelStreamContentDelta>().having((e) => e.text, 'text', 'answer'),
  isA<ModelStreamUsage>()
      .having((e) => e.promptTokens, 'promptTokens', 3)
      .having((e) => e.completionTokens, 'completionTokens', 4),
  isA<ModelStreamCompleted>(),
]
```

- [ ] Implement `StreamingModelProvider` on `OpenAiCompatibleProvider`.
- [ ] Request with:

```dart
data: {
  'model': model,
  'messages': [
    {'role': 'user', 'content': prompt},
  ],
  'stream': true,
}
```

- [ ] Call Dio as `post<ResponseBody>(...)` and use `Options(responseType: ResponseType.stream, headers: _headers(), sendTimeout: timeout, receiveTimeout: timeout)`.
- [ ] Import `dart:convert` and parse `res.data!.stream` as bytes, not as JSON: `response.stream.transform(utf8.decoder).transform(const LineSplitter())`.
- [ ] Parse SSE lines by trimming whitespace, skipping blank/comment lines, stripping a leading `data:` prefix plus optional following space, and stopping on `[DONE]`.
- [ ] Extract:
  - `choices[0].delta.reasoning_content` → `ModelStreamReasoningDelta`
  - `choices[0].delta.content` → `ModelStreamContentDelta`
  - `usage.prompt_tokens` / `usage.completion_tokens` → `ModelStreamUsage`
- [ ] Guard missing/empty `choices`, missing `delta`, and absent `usage` fields so ordinary final chunks do not throw.
- [ ] Yield `ModelStreamStarted` before reading the response body and exactly one `ModelStreamCompleted` when `[DONE]` is seen or the response stream ends.
- [ ] Keep non-streaming `generate(...)` unchanged.
- [ ] In the provider test, also verify the captured request has `stream: true` and `ResponseType.stream`, and include a case where one `data:` line is split across multiple byte chunks.
- [ ] Run:

```sh
flutter test test/providers/openai_compatible_provider_test.dart
```

Expected: all tests pass.

## Task 3: Progress Snapshot State

**Files:**
- Create: `lib/runner/run_progress_snapshot.dart`
- Modify: `lib/runner/run_state.dart`

- [ ] Create immutable `RunProgressSnapshot`:

```dart
import 'package:equatable/equatable.dart';

enum RunComboPhase {
  queued,
  requestingModel,
  streamingResponse,
  extractingCode,
  creatingWorkdir,
  preparing,
  evaluating,
  persisting,
}

class RunProgressSnapshot extends Equatable {
  const RunProgressSnapshot({
    required this.index,
    required this.label,
    required this.phase,
    required this.startedAt,
    this.reasoningPreview = '',
    this.answerPreview = '',
    this.promptTokens,
    this.completionTokens,
  });

  final int index;
  final String label;
  final RunComboPhase phase;
  final DateTime startedAt;
  final String reasoningPreview;
  final String answerPreview;
  final int? promptTokens;
  final int? completionTokens;

  RunProgressSnapshot copyWith({
    RunComboPhase? phase,
    String? reasoningPreview,
    String? answerPreview,
    int? promptTokens,
    int? completionTokens,
  }) {
    return RunProgressSnapshot(
      index: index,
      label: label,
      phase: phase ?? this.phase,
      startedAt: startedAt,
      reasoningPreview: reasoningPreview ?? this.reasoningPreview,
      answerPreview: answerPreview ?? this.answerPreview,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
    );
  }

  @override
  List<Object?> get props => [
        index,
        label,
        phase,
        startedAt,
        reasoningPreview,
        answerPreview,
        promptTokens,
        completionTokens,
      ];
}
```

- [ ] Update `RunInProgress`:

```dart
final List<RunProgressSnapshot> active;
```

Default to `const []`, remove `currentLabels`, include `active` in `props`, and update every `RunInProgress(...)` construction/destructure site in `lib/runner/run_bloc.dart` and `lib/ui/pages/run_progress_page.dart`.

## Task 4: RunBloc Streaming Progress

**Files:**
- Modify: `lib/runner/run_bloc.dart`
- Test: `test/runner/run_bloc_test.dart`

- [ ] Add active snapshot storage:

```dart
final active = <int, RunProgressSnapshot>{};
```

- [ ] Add helpers:
  - `_emitProgress(...)` that emits `RunInProgress(runId: ..., completed: resultSlots.whereType<TaskRunResult>().length, total: combos.length, results: List.unmodifiable(resultSlots.whereType<TaskRunResult>()), active: List.unmodifiable(active.values.toList()..sort((a, b) => a.index.compareTo(b.index))))`
  - `_trimPreview(String value)` retaining the last 16 KB
  - `_updateActive(...)` creating or replacing a `RunProgressSnapshot` entry instead of mutating an existing snapshot
- [ ] Use `now()` once when a combo first becomes active for `startedAt`; later phase/delta updates must preserve the original `startedAt`.

- [ ] Split `_runCombo` into phase-aware steps:
  - request/stream model
  - extract code
  - create workdir
  - prepare
  - evaluate
  - return result

- [ ] If `combo.provider is StreamingModelProvider`, consume `generateStream`.
  - Append reasoning deltas to `reasoningPreview`.
  - Append content deltas to `answerPreview`.
  - Build final raw text from content deltas only.
  - Update token counts from `ModelStreamUsage`.
  - Measure latency with a `Stopwatch` around stream consumption and use it in the final `ModelResponse`.
  - Emit after each non-empty delta.
- [ ] If provider is not streaming, keep existing `generate` behavior but emit phase changes.
  - After `generate` returns, set `answerPreview` to the trimmed `response.rawText` before moving to `extractingCode`.
- [ ] Preserve final `TaskRunResult.response.rawText` as the answer content, not reasoning.
- [ ] Remove the active snapshot in the worker after the result is persisted or after synthetic failure is persisted, then emit progress with the updated active list and completed count.
- [ ] Existing skip/fail behavior stays unchanged.
- [ ] Add tests:
  - streaming provider emits `RunInProgress.active` with reasoning and answer previews before completion.
  - final result raw text contains answer only.
  - non-streaming provider still emits phase snapshots and completes.

## Task 5: Progress UI

**Files:**
- Modify: `lib/ui/pages/run_progress_page.dart`
- Test: `test/ui/pages/run_progress_page_test.dart`

- [ ] Render:
  - `LinearProgressIndicator(value: total == 0 ? null : completed / total)`
  - `"$completed / $total completed"`
  - active cards sorted by index.
  - completed result cards below active cards while run is still in progress.
- [ ] Each active card shows:
  - label
  - phase label
  - elapsed seconds using `DateTime.now().difference(snapshot.startedAt)` inside `_ElapsedText`
  - token counts if present
  - collapsed `ExpansionTile(title: Text('Thinking'))`
  - collapsed `ExpansionTile(title: Text('Answer'))`
- [ ] If a stream has no reasoning, Thinking content says:

```txt
No thinking stream available yet.
```

- [ ] Keep expansion state stable across streaming rebuilds by using stable keys such as `PageStorageKey('thinking-${snapshot.index}')` and `PageStorageKey('answer-${snapshot.index}')`.
- [ ] Do not rely on bloc emissions to refresh elapsed time. Add a small `_ElapsedText` `StatefulWidget` with a one-second `Timer.periodic`, and dispose the timer.
- [ ] Add widget tests:
  - active snapshot renders label and phase.
  - Thinking and Answer panels show streamed text when expanded.
  - completed results render while in progress.

## Task 6: Verification

- [ ] Run:

```sh
dart format lib/providers/model_stream_event.dart lib/providers/model_provider.dart lib/providers/openai_compatible_provider.dart lib/runner/run_progress_snapshot.dart lib/runner/run_state.dart lib/runner/run_bloc.dart lib/ui/pages/run_progress_page.dart test/providers/openai_compatible_provider_test.dart test/runner/run_bloc_test.dart test/ui/pages/run_progress_page_test.dart
```

- [ ] Run:

```sh
flutter analyze
flutter test test/providers/openai_compatible_provider_test.dart test/runner/run_bloc_test.dart test/ui/pages/run_progress_page_test.dart
```

- [ ] Optional manual check with local llama-server:

```sh
curl -N http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.6-35b-a3b-apex-262k-rx9070xt-turbo3-coding","messages":[{"role":"user","content":"Say hello"}],"stream":true}'
```

Expected: chunks include `delta.reasoning_content` and/or `delta.content`.

## Out of Scope

- Persisting reasoning/thinking to Drift.
- Streaming Ollama `/api/generate`.
- Cancel button.
- Per-provider concurrency caps.
