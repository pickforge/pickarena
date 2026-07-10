import 'dart:io';

import 'package:dart_arena/agent/agent_harness.dart';
import 'package:dart_arena/agent/agent_run_result.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/runner/generated_code_sandbox.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:path/path.dart' as p;

class DeterministicFakeProvider
    with Disposable
    implements StreamingModelProvider {
  DeterministicFakeProvider({
    this.providerId = 'fake_headless',
    this.providerDisplayName = 'Fake Headless',
    this.modelId = 'fake-headless-model',
    this.rawText = '```dart\nString headlessAnswer() => \'phase7\';\n```',
    this.promptTokens = 11,
    this.completionTokens = 7,
    this.latency = const Duration(milliseconds: 3),
  });

  final String providerId;
  final String providerDisplayName;
  final String modelId;
  final String rawText;
  final int promptTokens;
  final int completionTokens;
  final Duration latency;
  var disposed = false;

  @override
  String get id => providerId;

  @override
  String get displayName => providerDisplayName;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<ModelInfo>> listModels() async => [ModelInfo(id: modelId)];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    if (model != modelId) {
      throw ArgumentError.value(model, 'model', 'unknown fake model');
    }
    return ModelResponse(
      rawText: rawText,
      extractedCode: null,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      latency: latency,
    );
  }

  @override
  Stream<ModelStreamEvent> generateStream({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async* {
    final response = await generate(
      prompt: prompt,
      model: model,
      timeout: timeout,
    );
    yield const ModelStreamStarted();
    yield ModelStreamContentDelta(response.rawText);
    yield ModelStreamUsage(
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
    );
    yield const ModelStreamCompleted();
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class FailingFakeProvider with Disposable implements ModelProvider {
  FailingFakeProvider({
    this.providerId = 'failing_headless',
    this.providerDisplayName = 'Failing Headless',
    this.modelId = 'failing-headless-model',
    this.errorMessage = 'deterministic provider failure',
  });

  final String providerId;
  final String providerDisplayName;
  final String modelId;
  final String errorMessage;
  var disposed = false;

  @override
  String get id => providerId;

  @override
  String get displayName => providerDisplayName;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<ModelInfo>> listModels() async => [ModelInfo(id: modelId)];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    throw StateError(errorMessage);
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class DeterministicFakeAgentHarness implements AgentHarness {
  DeterministicFakeAgentHarness({
    this.harnessId = 'fake_headless',
    this.modelId = 'fake-headless-model',
    this.generatedPath = 'lib/headless_answer.dart',
    this.generatedCode = "String headlessAnswer() => 'phase7';\n",
  });

  final String harnessId;
  final String modelId;
  final String generatedPath;
  final String generatedCode;
  var runCount = 0;

  @override
  String get id => harnessId;

  @override
  Future<AgentRunResult> run({
    required Directory workspace,
    required String instruction,
    required String modelId,
    required Duration timeout,
    Iterable<String> deniedEnvironmentKeys = const [],
  }) async {
    if (modelId != this.modelId) {
      throw ArgumentError.value(modelId, 'modelId', 'unknown fake model');
    }
    runCount++;
    final file = File(p.join(workspace.path, generatedPath));
    await file.parent.create(recursive: true);
    await file.writeAsString(generatedCode);
    return const AgentRunResult(
      status: AgentRunStatus.success,
      stdoutPreview: 'fake agent completed',
      stderrPreview: '',
      exitCode: 0,
      latency: Duration(milliseconds: 5),
      promptTokens: 17,
      completionTokens: 11,
    );
  }
}

class NoOpPrepareWorkdirManager extends WorkdirManager {
  NoOpPrepareWorkdirManager({required super.root});

  @override
  Future<PrepareResult> prepare(
    Directory workDir, {
    bool isFlutter = false,
    bool allowInternet = true,
    WorkdirRemainingTimeout? remainingTimeout,
    WorkdirCancellationCheck? cancellationCheck,
    Future<void>? cancellationSignal,
    GeneratedCodeSandbox? generatedCodeSandbox,
    int? maxCpuCores,
  }) async {
    return const PrepareOk();
  }
}

class FixedRunProvenanceEnvironmentProvider
    implements RunProvenanceEnvironmentProvider {
  const FixedRunProvenanceEnvironmentProvider([
    this.environment = const {
      'hostPlatform': 'test-os',
      'operatingSystemVersion': 'test-os-version',
      'locale': 'en_US',
      'dartVersion': 'test-dart',
      'flutterVersion': 'test-flutter',
      'gitCommit': 'test-git',
      'gitDirty': false,
    },
  ]);

  final Map<String, Object?> environment;

  @override
  Future<Map<String, Object?>> capture() async => environment;
}
