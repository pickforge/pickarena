import 'dart:convert';
import 'dart:io';

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
import 'package:dart_arena/runner/resource_enforcement_policy.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/run_provenance.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;

class _FixedEnvironment implements RunProvenanceEnvironmentProvider {
  @override
  Future<Map<String, Object?>> capture() async => const {
    'hostPlatform': 'test-os',
    'dartVersion': 'test-dart',
    'flutterVersion': 'test-flutter',
    'gitCommit': 'abc123',
    'gitDirty': false,
    'dependencySnapshot': {
      'status': 'present',
      'files': {
        'pubspec.lock': {
          'sha256':
              'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd',
          'bytes': 42,
        },
      },
    },
  };
}

class _SecretProvider
    with Disposable
    implements ModelProvider, ModelRuntimeMetadataProvider {
  final apiKey = 'sk-secret-value';
  final secretHeaders = const {'Authorization': 'Bearer secret-header-value'};

  @override
  String get id => 'secret-provider';
  @override
  String get displayName => 'Secret Provider';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  @override
  Map<String, Object?> providerRuntimeConfig() => const {
    'providerMode': 'rawApi',
    'requestProtocol': 'test_chat',
  };

  @override
  Map<String, Object?> modelRuntimeConfig(String modelId) => const {
    'maxOutputTokens': 4096,
    'temperature': {'configured': false, 'status': 'provider_default'},
    'toolPolicy': 'none',
    'retryPolicy': {
      'maxRetries': 2,
      'retryStatusCodes': [429],
      'backoffSeconds': [1, 2],
    },
  };

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
  TaskResourceLimits get resourceLimits => const TaskResourceLimits(
    cpus: 2,
    memoryMb: 8192,
    maxProcesses: 64,
    maxOutputBytes: 1048576,
  );
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

class _PartialResourceTask extends _SensitiveTask {
  @override
  String get id => 'partial-resource-task';

  @override
  TaskResourceLimits get resourceLimits =>
      const TaskResourceLimits(maxOutputBytes: 2048);
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
          'secret-provider': ['model-a::high', 'model-b'],
        },
        combos: [
          RunProvenanceCombo(
            index: 0,
            task: task,
            providerId: 'secret-provider',
            modelId: 'model-a::high',
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
      expect(config['generatedCodeSandbox'], {
        'required': false,
        'enforced': false,
      });
      final pricingRegistry = config['pricingRegistry'] as Map<String, Object?>;
      expect(pricingRegistry['version'], '2026-05-31');
      expect(pricingRegistry['currency'], 'USD');
      expect(pricingRegistry['modelCount'], greaterThan(0));
      final pricingModels = pricingRegistry['models'] as Map<String, Object?>;
      final gptPricing =
          pricingModels['openai:gpt-5.3-codex'] as Map<String, Object?>;
      expect(gptPricing['source'], 'manual');
      expect(gptPricing['effectiveFrom'], '2026-05-31');
      expect(
        ((config['modelsByProvider'] as Map<String, Object?>)['secret-provider']
            as List),
        ['model-a::high', 'model-b'],
      );
      expect(config['scoringSchemaVersion'], 2);
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
      expect(taskJson['executionPolicy'], {
        'allowInternet': false,
        'resources': {
          'cpus': 2,
          'memoryMb': 8192,
          'maxProcesses': 64,
          'maxOutputBytes': 1048576,
        },
        'resourceEnforcement': taskResourceEnforcementJson(),
      });
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
      final hiddenVerifierDigests =
          taskJson['hiddenVerifierDigests'] as Map<String, Object?>;
      expect(hiddenVerifierDigests.keys, ['hidden_test']);
      expect(hiddenVerifierDigests['hidden_test'], isA<String>());
      expect((hiddenVerifierDigests['hidden_test']! as String), hasLength(64));

      final providerJson =
          (decoded['providers'] as List).single as Map<String, Object?>;
      expect(providerJson['id'], 'secret-provider');
      expect(providerJson['runtimeConfig'], {
        'providerMode': 'rawApi',
        'requestProtocol': 'test_chat',
      });
      expect(providerJson['selectedModels'], ['model-a::high', 'model-b']);
      expect(providerJson['selectedModelConfigs'], [
        {
          'modelId': 'model-a::high',
          'baseModelId': 'model-a',
          'modelConfig': {
            'effort': 'high',
            'maxOutputTokens': 4096,
            'retryPolicy': {
              'backoffSeconds': [1, 2],
              'maxRetries': 2,
              'retryStatusCodes': [429],
            },
            'temperature': {'configured': false, 'status': 'provider_default'},
            'toolPolicy': 'none',
          },
        },
        {
          'modelId': 'model-b',
          'baseModelId': 'model-b',
          'modelConfig': {
            'maxOutputTokens': 4096,
            'retryPolicy': {
              'backoffSeconds': [1, 2],
              'maxRetries': 2,
              'retryStatusCodes': [429],
            },
            'temperature': {'configured': false, 'status': 'provider_default'},
            'toolPolicy': 'none',
          },
        },
      ]);
      expect(providerJson['secretsRedacted'], isTrue);

      final comboJson =
          (decoded['combos'] as List).single as Map<String, Object?>;
      expect(comboJson['modelId'], 'model-a::high');
      expect(comboJson['baseModelId'], 'model-a');
      expect(comboJson['modelConfig'], {
        'effort': 'high',
        'maxOutputTokens': 4096,
        'retryPolicy': {
          'backoffSeconds': [1, 2],
          'maxRetries': 2,
          'retryStatusCodes': [429],
        },
        'temperature': {'configured': false, 'status': 'provider_default'},
        'toolPolicy': 'none',
      });

      final environment = decoded['environment'] as Map<String, Object?>;
      expect(environment['dartVersion'], 'test-dart');
      expect(environment['flutterVersion'], 'test-flutter');
      final dependencySnapshot =
          environment['dependencySnapshot'] as Map<String, Object?>;
      expect(dependencySnapshot['status'], 'present');
      final dependencyFiles =
          dependencySnapshot['files'] as Map<String, Object?>;
      final pubspecLock =
          dependencyFiles['pubspec.lock'] as Map<String, Object?>;
      expect(pubspecLock['sha256'], isA<String>());
      expect(pubspecLock['bytes'], 42);

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

  test('provenance records effective resource limits with defaults', () async {
    final task = _PartialResourceTask();
    final jsonText = await buildRunProvenanceJson(
      runId: 'run-1',
      event: StartRun(
        tasks: [task],
        providers: const [],
        modelsByProvider: const {},
        evaluatorConfig: const EvaluatorConfig(),
      ),
      normalizedModelsByProvider: const {},
      combos: const [],
      evaluatorWeights: const {},
      capturedAt: DateTime.utc(2026, 6, 5),
      environmentProvider: _FixedEnvironment(),
    );

    final decoded = jsonDecode(jsonText) as Map<String, Object?>;
    final taskJson = (decoded['tasks'] as List).single as Map<String, Object?>;
    expect(taskJson['executionPolicy'], {
      'allowInternet': false,
      'resources': {
        'cpus': 2,
        'memoryMb': 8192,
        'maxProcesses': 64,
        'maxOutputBytes': 2048,
      },
      'resourceEnforcement': taskResourceEnforcementJson(),
    });
  });

  test(
    'default environment provider scrubs helper subprocess environment',
    () async {
      final tmp = await Directory.systemTemp.createTemp(
        'dart_arena_provenance_env_',
      );
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      await File(
        p.join(tmp.path, 'pubspec.yaml'),
      ).writeAsString('name: provenance_env_test\n');
      final bin = Directory(p.join(tmp.path, 'bin'))..createSync();
      final log = File(p.join(tmp.path, 'helper_env.log'));
      await _writeExecutable(bin, 'git', '''
#!/bin/sh
{
  echo "git SECRET_TOKEN=\${SECRET_TOKEN:-}"
  echo "git HTTP_PROXY=\${HTTP_PROXY:-}"
  echo "git NORMAL_VALUE=\${NORMAL_VALUE:-}"
} >> "\$LOG_PATH"
if [ "\$1" = "rev-parse" ]; then
  echo "0123456789abcdef0123456789abcdef01234567"
  exit 0
fi
if [ "\$1" = "status" ]; then
  exit 0
fi
exit 1
''');
      await _writeExecutable(bin, 'flutter', '''
#!/bin/sh
{
  echo "flutter SECRET_TOKEN=\${SECRET_TOKEN:-}"
  echo "flutter HTTP_PROXY=\${HTTP_PROXY:-}"
  echo "flutter NORMAL_VALUE=\${NORMAL_VALUE:-}"
} >> "\$LOG_PATH"
printf '{"frameworkVersion":"test-flutter"}'
''');

      final path = [
        bin.path,
        if ((Platform.environment['PATH'] ?? '').isNotEmpty)
          Platform.environment['PATH']!,
      ].join(':');
      final environment = await DefaultRunProvenanceEnvironmentProvider(
        timeout: const Duration(seconds: 2),
        dependencyRoot: tmp,
        baseEnvironment: {
          'PATH': path,
          'LOG_PATH': log.path,
          'SECRET_TOKEN': 'secret-token-value',
          'HTTP_PROXY': 'http://proxy-secret.invalid',
          'NORMAL_VALUE': 'visible',
        },
      ).capture();

      expect(environment['flutterVersion'], 'test-flutter');
      expect(
        environment['gitCommit'],
        '0123456789abcdef0123456789abcdef01234567',
      );
      expect(environment['gitDirty'], isFalse);
      final helperLog = await log.readAsString();
      expect(helperLog, contains('git NORMAL_VALUE=visible'));
      expect(helperLog, contains('flutter NORMAL_VALUE=visible'));
      expect(helperLog, isNot(contains('secret-token-value')));
      expect(helperLog, isNot(contains('proxy-secret')));
    },
    skip: Platform.isWindows,
  );
}

Future<File> _writeExecutable(
  Directory directory,
  String name,
  String contents,
) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsString(contents);
  final chmod = await Process.run('chmod', ['+x', file.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
  return file;
}
