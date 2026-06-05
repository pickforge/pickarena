import 'dart:io';

import 'package:dart_arena/core/scoring.dart';
import 'package:dart_arena/headless/headless_cli_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Headless CLI config parser', () {
    test('rejects malformed JSON files', () async {
      final tmp = await Directory.systemTemp.createTemp('dart_arena_bad_json_');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });
      final file = File(p.join(tmp.path, 'run.json'));
      await file.writeAsString('{not json');

      await expectLater(
        loadHeadlessCliConfig(file),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('invalid JSON'),
          ),
        ),
      );
    });

    test('accepts valid JSON and resolves paths relative to config file', () {
      final config = parseHeadlessCliConfig(
        _validConfig(),
        configPath: p.join(Directory.current.path, 'configs', 'run.json'),
      );

      expect(config.runId, 'nightly-2026-05-30');
      expect(config.tasks, ['bug.off_by_one_pagination']);
      expect(config.providers.single.id, 'openai');
      expect(config.providers.single.models, ['gpt-5.5']);
      expect(config.judge!.providerId, 'openai');
      expect(config.taskBundleRoots, isEmpty);
      expect(config.maxConcurrency, 2);
      expect(config.trialsPerTask, 1);
      expect(config.requireGeneratedCodeSandbox, isFalse);
      expect(config.timeout, const Duration(seconds: 600));
      expect(
        config.workdirRoot,
        p.normalize(
          p.join(Directory.current.path, 'configs', '.dart_arena', 'workdirs'),
        ),
      );
      expect(
        config.outputDir,
        p.normalize(
          p.join(Directory.current.path, 'configs', '.dart_arena', 'bundles'),
        ),
      );
      expect(
        config.databasePath,
        p.normalize(
          p.join(
            Directory.current.path,
            'configs',
            '.dart_arena',
            'dart_arena.sqlite',
          ),
        ),
      );
    });

    test('resolves file-backed task bundle roots relative to config', () {
      final config = parseHeadlessCliConfig({
        ..._validConfig(),
        'taskBundleRoots': ['tasks/flutter', '/abs/tasks'],
      }, configPath: p.join(Directory.current.path, 'configs', 'run.json'));

      expect(config.taskBundleRoots, [
        p.normalize(p.join(Directory.current.path, 'configs', 'tasks/flutter')),
        p.normalize('/abs/tasks'),
      ]);
    });

    test('parses generated-code sandbox requirement flag', () {
      final config = parseHeadlessCliConfig({
        ..._validConfig(),
        'requireGeneratedCodeSandbox': true,
      }, configPath: p.join(Directory.current.path, 'run.json'));

      expect(config.requireGeneratedCodeSandbox, isTrue);
    });

    test('rejects malformed required fields and types', () {
      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'runId': 7,
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('runId must be a string'),
          ),
        ),
      );
      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'tasks': <Object?>[],
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('tasks must not be empty'),
          ),
        ),
      );
      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'timeoutSeconds': 0,
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('timeoutSeconds must be a positive integer'),
          ),
        ),
      );
      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'requireGeneratedCodeSandbox': 'yes',
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('requireGeneratedCodeSandbox must be a boolean'),
          ),
        ),
      );
    });

    test('rejects malicious runId and provider IDs', () {
      for (final runId in ['../run', 'bad/run', r'bad\run', 'run..id']) {
        expect(
          () => parseHeadlessCliConfig({
            ..._validConfig(),
            'runId': runId,
          }, configPath: p.join(Directory.current.path, 'run.json')),
          throwsA(isA<HeadlessCliConfigException>()),
        );
      }

      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'providers': [
            {
              'type': 'openai_compatible',
              'id': '../local',
              'displayName': 'Local',
              'baseUrl': 'http://127.0.0.1:11434/v1',
              'models': ['m'],
            },
          ],
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('providers[0].id must be a safe path segment'),
          ),
        ),
      );
    });

    test('model-derived workdir segments are always safe', () {
      for (final model in [
        '.',
        '..',
        'openai/gpt-5',
        r'bad\model',
        '/abs',
        r'C:\abs\model',
      ]) {
        final segment = safeModelPathSegment(model);
        expect(segment, isNot(isEmpty));
        expect(segment, isNot('.'));
        expect(segment, isNot('..'));
        expect(segment, isNot(contains('/')));
        expect(segment, isNot(contains('\\')));
        expect(p.isAbsolute(segment), isFalse);
      }
    });

    test('evaluatorWeights omitted or empty uses defaults', () {
      var config = parseHeadlessCliConfig(
        _validConfig()..remove('evaluatorWeights'),
        configPath: p.join(Directory.current.path, 'run.json'),
      );
      expect(config.evaluatorWeights, defaultEvaluatorWeights);

      config = parseHeadlessCliConfig({
        ..._validConfig(),
        'evaluatorWeights': <String, Object?>{},
      }, configPath: p.join(Directory.current.path, 'run.json'));
      expect(config.evaluatorWeights, defaultEvaluatorWeights);
    });

    test(
      'evaluatorWeights overrides defaults and rejects malformed values',
      () {
        final config = parseHeadlessCliConfig({
          ..._validConfig(),
          'evaluatorWeights': {'compile': 2.5},
        }, configPath: p.join(Directory.current.path, 'run.json'));
        expect(config.evaluatorWeights['compile'], 2.5);
        expect(
          config.evaluatorWeights['test'],
          defaultEvaluatorWeights['test'],
        );

        for (final value in ['bad', -1, double.nan, double.infinity]) {
          expect(
            () => parseHeadlessCliConfig({
              ..._validConfig(),
              'evaluatorWeights': {'compile': value},
            }, configPath: p.join(Directory.current.path, 'run.json')),
            throwsA(isA<HeadlessCliConfigException>()),
          );
        }
      },
    );

    test('rejects outputDir inside workdirRoot runs directory', () {
      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'workdirRoot': 'workdirs',
          'outputDir': 'workdirs/runs/bundles',
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('outputDir must not be inside workdirRoot/runs'),
          ),
        ),
      );
    });

    test('rejects unknown provider type and judge provider mismatch', () {
      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'providers': [
            {
              'type': 'openai',
              'models': ['gpt-5.5'],
              'apiKeyEnv': 'OPENAI_API_KEY',
            },
            {
              'type': 'openai_compatible',
              'id': 'openai',
              'displayName': 'Duplicate',
              'baseUrl': 'http://127.0.0.1:11434/v1',
              'models': ['local'],
            },
          ],
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('duplicate provider id: openai'),
          ),
        ),
      );

      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'providers': [
            {
              'type': 'unknown',
              'models': ['m'],
            },
          ],
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('unsupported provider type: unknown'),
          ),
        ),
      );

      expect(
        () => parseHeadlessCliConfig({
          ..._validConfig(),
          'judge': {'providerId': 'missing', 'model': 'judge'},
        }, configPath: p.join(Directory.current.path, 'run.json')),
        throwsA(
          isA<HeadlessCliConfigException>().having(
            (e) => e.message,
            'message',
            contains('judge providerId does not match'),
          ),
        ),
      );
    });
  });
}

Map<String, Object?> _validConfig() {
  return {
    'runId': 'nightly-2026-05-30',
    'name': 'Nightly benchmark',
    'tasks': ['bug.off_by_one_pagination'],
    'providers': [
      {
        'type': 'openai',
        'models': ['gpt-5.5'],
        'apiKeyEnv': 'OPENAI_API_KEY',
      },
    ],
    'judge': {'providerId': 'openai', 'model': 'gpt-5.5'},
    'evaluatorWeights': <String, Object?>{},
    'maxConcurrency': 2,
    'trialsPerTask': 1,
    'useReferencePlan': false,
    'workdirRoot': '.dart_arena/workdirs',
    'outputDir': '.dart_arena/bundles',
    'databasePath': '.dart_arena/dart_arena.sqlite',
    'timeoutSeconds': 600,
  };
}
