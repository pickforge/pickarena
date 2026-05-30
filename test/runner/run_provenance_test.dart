import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/evaluator_config.dart';
import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/core/reference_solution.dart';
import 'package:dart_arena/core/task_verifier.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedEnvironment implements RunProvenanceEnvironmentProvider {
  @override
  Future<Map<String, Object?>> capture() async => const {
    'hostPlatform': 'test-os',
    'dartVersion': 'test-dart',
    'flutterVersion': 'test-flutter',
    'gitCommit': 'abc123',
    'gitDirty': false,
  };
}

class _SecretProvider with Disposable implements ModelProvider {
  final apiKey = 'sk-secret-value';
  final secretHeaders = const {'Authorization': 'Bearer secret-header-value'};

  @override
  String get id => 'secret-provider';
  @override
  String get displayName => 'Secret Provider';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Future<List<ModelInfo>> listModels() async => const [
    ModelInfo(id: 'model-a'),
  ];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    throw UnimplementedError();
  }
}

class _AlwaysPass implements Evaluator {
  @override
  String get id => 'pass';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async =>
      const EvaluationResult(evaluatorId: 'pass', passed: true, score: 1);
}

class _SensitiveTask extends BenchmarkTask {
  @override
  String get id => 'sensitive-task';
  @override
  int get version => 3;
  @override
  Category get category => Category.bugFix;
  @override
  BenchmarkTrack get track => BenchmarkTrack.agentic;
  @override
  Set<TaskTag> get tags => const {TaskTag.bugfix, TaskTag.testing};
  @override
  TaskDifficulty get difficulty => TaskDifficulty.hard;
  @override
  Duration? get timeout => const Duration(minutes: 5);
  @override
  Set<TaskPlatform> get platformRequirements => const {TaskPlatform.linux};
  @override
  String get prompt => 'prompt-secret-content';
  @override
  Map<String, String> get fixtures => const {
    'pubspec.yaml': 'public-fixture-content',
    'test/_hidden/secret_test.dart': 'hidden-fixture-secret',
    'reference/lib/answer.dart': 'reference-fixture-secret',
  };
  @override
  List<VerifierFixture> get hiddenVerifiers => const [
    VerifierFixture(
      files: {'test/secret_test.dart': 'hidden-verifier-secret'},
      testPath: 'test/secret_test.dart',
    ),
  ];
  @override
  ReferenceSolution? get referenceSolution =>
      const ReferenceFileSolution({'lib/answer.dart': 'reference-secret'});
  @override
  String get generatedCodePath => 'lib/answer.dart';
  @override
  String? get judgeRubric => null;
  @override
  bool get isFlutter => true;
  @override
  List<Evaluator> evaluatorsFor(EvaluatorConfig config) => [_AlwaysPass()];
}

void main() {
  test(
    'provenance v1 records safe metadata and redacts sensitive data',
    () async {
      final provider = _SecretProvider();
      final task = _SensitiveTask();
      final jsonText = await buildRunProvenanceJson(
        runId: 'run-1',
        event: StartRun(
          tasks: [task],
          providers: [provider],
          modelsByProvider: const {
            'secret-provider': [' model-a ', 'model-a', 'model-b'],
          },
          evaluatorConfig: EvaluatorConfig(
            judgeProvider: provider,
            judgeModel: 'judge-model',
          ),
          useReferencePlan: true,
          maxConcurrency: 99,
          trialsPerTask: 0,
        ),
        normalizedModelsByProvider: const {
          'secret-provider': ['model-a', 'model-b'],
        },
        combos: [
          RunProvenanceCombo(
            index: 0,
            task: task,
            providerId: 'secret-provider',
            modelId: 'model-a',
            trialIndex: 0,
            planId: 'plan-1',
          ),
        ],
        evaluatorWeights: const {'hidden_test': 1, 'compile': 0.2},
        capturedAt: DateTime.utc(2026, 5, 30),
        environmentProvider: _FixedEnvironment(),
      );

      final decoded = jsonDecode(jsonText) as Map<String, Object?>;
      expect(decoded['schemaVersion'], 1);
      expect(decoded['runId'], 'run-1');

      final config = decoded['config'] as Map<String, Object?>;
      expect(config['maxConcurrency'], 8);
      expect(config['trialsPerTask'], 1);
      expect(
        ((config['modelsByProvider'] as Map<String, Object?>)['secret-provider']
            as List),
        ['model-a', 'model-b'],
      );
      expect(config['evaluatorWeights'], {'compile': 0.2, 'hidden_test': 1.0});
      expect(config['judge'], {
        'providerId': 'secret-provider',
        'modelId': 'judge-model',
      });

      final taskJson =
          (decoded['tasks'] as List).single as Map<String, Object?>;
      expect(taskJson['version'], 3);
      expect(taskJson['category'], 'bugFix');
      expect(taskJson['track'], 'agentic');
      expect(taskJson['tags'], ['bugfix', 'testing']);
      expect(taskJson['difficulty'], 'hard');
      expect(taskJson['timeoutMs'], 300000);
      expect(taskJson['platformRequirements'], ['linux']);
      expect(taskJson['generatedCodePath'], 'lib/answer.dart');
      expect(taskJson['isFlutter'], isTrue);
      expect(
        taskJson['promptSha256'],
        sha256.convert(utf8.encode('prompt-secret-content')).toString(),
      );
      expect(taskJson['hiddenAssetsExcluded'], isTrue);
      expect((taskJson['publicFixtureDigests'] as Map<String, Object?>).keys, [
        'pubspec.yaml',
      ]);

      final providerJson =
          (decoded['providers'] as List).single as Map<String, Object?>;
      expect(providerJson['id'], 'secret-provider');
      expect(providerJson['selectedModels'], ['model-a', 'model-b']);
      expect(providerJson['secretsRedacted'], isTrue);

      expect(jsonText, isNot(contains(provider.apiKey)));
      expect(
        jsonText,
        isNot(contains(provider.secretHeaders['Authorization']!)),
      );
      expect(jsonText, isNot(contains('prompt-secret-content')));
      expect(jsonText, isNot(contains('hidden-fixture-secret')));
      expect(jsonText, isNot(contains('hidden-verifier-secret')));
      expect(jsonText, isNot(contains('reference-secret')));
      expect(jsonText, isNot(contains('reference-fixture-secret')));
    },
  );
}
