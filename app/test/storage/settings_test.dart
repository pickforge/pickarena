import 'dart:convert';
import 'dart:io';

import 'package:dart_arena/storage/file_settings_store.dart';
import 'package:dart_arena/storage/settings_store.dart';
import 'package:test/test.dart';

import '../support/settings_store_test_utils.dart';

int _permissionBits(FileStat stat) => stat.mode & 0x1ff;

Future<void> _chmod(String mode, String path) async {
  final result = await Process.run('chmod', [mode, path]);
  if (result.exitCode != 0) {
    throw StateError(result.stderr.toString());
  }
}

void main() {
  test('default Ollama URL is localhost:11434', () async {
    final repo = await newFileSettingsStore();
    expect(await repo.getOllamaBaseUrl(), 'http://localhost:11434');
  });

  test('setOllamaBaseUrl roundtrips', () async {
    final repo = await newFileSettingsStore();
    await repo.setOllamaBaseUrl('http://example.com:11434');
    expect(await repo.getOllamaBaseUrl(), 'http://example.com:11434');
  });

  test('per-provider api keys roundtrip', () async {
    final repo = await newFileSettingsStore();
    expect(await repo.getApiKey('opencode_go'), isNull);
    await repo.setApiKey('opencode_go', 'sk-go-1');
    expect(await repo.getApiKey('opencode_go'), 'sk-go-1');
    await repo.clearApiKey('opencode_go');
    expect(await repo.getApiKey('opencode_go'), isNull);
  });

  test('ollama cloud key has its own slot', () async {
    final repo = await newFileSettingsStore();
    await repo.setApiKey('ollama_cloud', 'cloud-token');
    expect(await repo.getApiKey('ollama_cloud'), 'cloud-token');
  });

  test('api key env override wins over stored value', () async {
    final repo = await newFileSettingsStore(
      environment: const {'DART_ARENA_API_KEY_OPENAI': 'env-key'},
    );
    await repo.setApiKey('openai', 'stored-key');
    expect(await repo.getApiKey('openai'), 'env-key');
  });

  test('env-backed api keys are not persisted to disk', () async {
    final fixture = await newSettingsFilePath();
    final env = {'DART_ARENA_API_KEY_OPENAI': 'env-key'};
    final repo = FileSettingsStore(path: fixture.path, environment: env);

    await repo.setApiKey('openai', 'disk-key');

    final raw = await File(fixture.path).readAsString();
    expect(raw, isNot(contains('disk-key')));
    expect(raw, isNot(contains('"apiKey"')));

    final reloaded = FileSettingsStore(path: fixture.path, environment: env);
    expect(await reloaded.getApiKey('openai'), 'env-key');
  });

  test('apiKeyEnv from JSON resolves provider key', () async {
    final fixture = await newSettingsFilePath();
    await File(fixture.path).writeAsString(
      jsonEncode({
        'providers': {
          'openai': {'apiKey': 'stored-key', 'apiKeyEnv': 'OPENAI_API_KEY'},
        },
      }),
    );
    final repo = FileSettingsStore(
      path: fixture.path,
      environment: const {'OPENAI_API_KEY': 'env-key'},
    );
    expect(await repo.getApiKey('openai'), 'env-key');
  });

  test('apiKeyEnv strips plaintext api keys on persist', () async {
    final fixture = await newSettingsFilePath();
    await File(fixture.path).writeAsString(
      jsonEncode({
        'providers': {
          'openai': {'apiKeyEnv': 'OPENAI_API_KEY', 'apiKey': 'old-key'},
        },
      }),
    );
    final env = {'OPENAI_API_KEY': 'env-key'};
    final repo = FileSettingsStore(path: fixture.path, environment: env);

    await repo.setApiKey('openai', 'new-key');

    final raw = await File(fixture.path).readAsString();
    expect(raw, isNot(contains('old-key')));
    expect(raw, isNot(contains('new-key')));
    expect(await repo.getApiKey('openai'), 'env-key');
  });

  test('uses DART_ARENA_SETTINGS when no explicit path is provided', () async {
    final fixture = await newSettingsFilePath();
    final env = {dartArenaSettingsEnv: fixture.path};
    final repo = FileSettingsStore(environment: env);
    await repo.setReadmePath('/tmp/README.md');

    final second = FileSettingsStore(environment: env);
    expect(await second.getReadmePath(), '/tmp/README.md');
  });

  test('base URL override roundtrips', () async {
    final repo = await newFileSettingsStore();
    expect(await repo.getBaseUrlOverride('ollama_cloud'), isNull);
    await repo.setBaseUrlOverride(
      'ollama_cloud',
      'https://my-ollama.example.com',
    );
    expect(
      await repo.getBaseUrlOverride('ollama_cloud'),
      'https://my-ollama.example.com',
    );
  });

  test(
    'creates default settings directory with owner-only permissions',
    () async {
      final home = await Directory.systemTemp.createTemp(
        'dart_arena_settings_home_',
      );
      addTearDown(() => home.delete(recursive: true));

      final repo = FileSettingsStore(environment: {'HOME': home.path});
      await repo.setReadmePath('/tmp/README.md');

      final settingsDir = Directory('${home.path}/.dart_arena');
      final settingsFile = File('${settingsDir.path}/settings.json');
      expect(_permissionBits(await settingsDir.stat()), 0x1c0);
      expect(_permissionBits(await settingsFile.stat()), 0x180);
    },
    skip: Platform.isWindows,
  );

  test(
    'DART_ARENA_SETTINGS path does not chmod parent directory',
    () async {
      final fixture = await newSettingsFilePath();
      final repo = FileSettingsStore(
        environment: {dartArenaSettingsEnv: fixture.path},
      );

      await _chmod('777', fixture.dir.path);
      await repo.setReadmePath('/tmp/README.md');

      expect(_permissionBits(await fixture.dir.stat()), 0x1ff);
      expect(_permissionBits(await File(fixture.path).stat()), 0x180);
    },
    skip: Platform.isWindows,
  );

  test(
    'explicit settings path does not chmod parent directory',
    () async {
      final fixture = await newSettingsFilePath();
      final repo = FileSettingsStore(path: fixture.path, environment: const {});

      await _chmod('777', fixture.dir.path);
      await repo.setReadmePath('/tmp/README.md');

      expect(_permissionBits(await fixture.dir.stat()), 0x1ff);
      expect(_permissionBits(await File(fixture.path).stat()), 0x180);
    },
    skip: Platform.isWindows,
  );

  test('serializes concurrent updates without dropping writes', () async {
    final fixture = await newSettingsFilePath();
    final repo = FileSettingsStore(path: fixture.path, environment: const {});

    await Future.wait([
      repo.setReadmePath('/tmp/README.md'),
      for (var i = 0; i < 20; i++) repo.setApiKey('provider_$i', 'sk-$i'),
    ]);

    final reloaded = FileSettingsStore(
      path: fixture.path,
      environment: const {},
    );
    expect(await reloaded.getReadmePath(), '/tmp/README.md');
    for (var i = 0; i < 20; i++) {
      expect(await reloaded.getApiKey('provider_$i'), 'sk-$i');
    }
  });

  test('serializes concurrent updates across stores for same path', () async {
    final fixture = await newSettingsFilePath();
    final first = FileSettingsStore(path: fixture.path, environment: const {});
    final second = FileSettingsStore(path: fixture.path, environment: const {});

    await Future.wait([
      first.setApiKey('openai', 'sk-test'),
      second.setReadmePath('/tmp/README.md'),
    ]);

    final reloaded = FileSettingsStore(
      path: fixture.path,
      environment: const {},
    );
    expect(await reloaded.getApiKey('openai'), 'sk-test');
    expect(await reloaded.getReadmePath(), '/tmp/README.md');
  });

  test('atomic writes leave no temporary settings files', () async {
    final fixture = await newSettingsFilePath();
    final repo = FileSettingsStore(path: fixture.path, environment: const {});

    await repo.setReadmePath('/tmp/README.md');
    await repo.setApiKey('openai', 'sk-test');

    final tempFiles = await fixture.dir
        .list()
        .where((entity) => entity.path.endsWith('.tmp'))
        .toList();
    expect(tempFiles, isEmpty);

    final decoded =
        jsonDecode(await File(fixture.path).readAsString())
            as Map<String, Object?>;
    expect(decoded['readmePath'], '/tmp/README.md');
  });

  test('atomic writes replace read-only settings file', () async {
    final fixture = await newSettingsFilePath();
    final file = File(fixture.path);
    await file.writeAsString(jsonEncode({'runConcurrency': 2}));
    await _chmod('400', file.path);

    final repo = FileSettingsStore(path: fixture.path, environment: const {});
    await repo.setReadmePath('/tmp/README.md');

    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, Object?>;
    expect(decoded['runConcurrency'], 2);
    expect(decoded['readmePath'], '/tmp/README.md');
    expect(_permissionBits(await file.stat()), 0x180);
  }, skip: Platform.isWindows);

  test(
    'backup replacement restores old settings when replacement fails',
    () async {
      final fixture = await newSettingsFilePath();
      final file = File(fixture.path);
      await file.writeAsString(jsonEncode({'readmePath': '/tmp/old.md'}));
      var replacementAttempts = 0;

      final repo = FileSettingsStore(
        path: fixture.path,
        environment: const {},
        replaceWithBackup: true,
        renameFile: (file, newPath) async {
          if (file.path.endsWith('.tmp') && newPath == fixture.path) {
            replacementAttempts++;
            throw FileSystemException('rename failed', newPath);
          }
          return file.rename(newPath);
        },
      );

      await expectLater(
        () => repo.setReadmePath('/tmp/new.md'),
        throwsA(isA<FileSystemException>()),
      );

      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      expect(decoded['readmePath'], '/tmp/old.md');
      expect(replacementAttempts, 1);
      final leftovers = await fixture.dir
          .list()
          .where(
            (entity) =>
                entity.path.endsWith('.tmp') || entity.path.endsWith('.bak'),
          )
          .toList();
      expect(leftovers, isEmpty);
    },
  );

  test('reads restore backup when settings file is missing', () async {
    final fixture = await newSettingsFilePath();
    final backup = File('${fixture.dir.path}/.settings.json.1.0.bak');
    await backup.writeAsString(jsonEncode({'readmePath': '/tmp/from-bak.md'}));

    final repo = FileSettingsStore(path: fixture.path, environment: const {});

    expect(await repo.getReadmePath(), '/tmp/from-bak.md');
    expect(await File(fixture.path).exists(), isTrue);
    expect(await backup.exists(), isFalse);
  });

  test('run concurrency defaults to 4', () async {
    final repo = await newFileSettingsStore();
    expect(await repo.getRunConcurrency(), 4);
  });

  test('run concurrency roundtrips', () async {
    final repo = await newFileSettingsStore();
    await repo.setRunConcurrency(7);
    expect(await repo.getRunConcurrency(), 7);
  });

  test('run concurrency clamps low values', () async {
    final repo = await newFileSettingsStore();
    await repo.setRunConcurrency(0);
    expect(await repo.getRunConcurrency(), 1);
  });

  test('run concurrency clamps high values', () async {
    final repo = await newFileSettingsStore();
    await repo.setRunConcurrency(100);
    expect(await repo.getRunConcurrency(), 8);
  });

  test('run concurrency falls back for invalid stored value', () async {
    final fixture = await newSettingsFilePath();
    await File(
      fixture.path,
    ).writeAsString(jsonEncode({'runConcurrency': 'abc'}));
    final repo = FileSettingsStore(path: fixture.path, environment: const {});
    expect(await repo.getRunConcurrency(), 4);
  });

  test('malformed settings JSON throws actionable error', () async {
    final fixture = await newSettingsFilePath();
    final file = File(fixture.path);
    const raw = '{"providers":';
    await file.writeAsString(raw);
    final repo = FileSettingsStore(path: fixture.path, environment: const {});

    Object? error;
    try {
      await repo.getReadmePath();
    } on Object catch (caught) {
      error = caught;
    }

    expect(error, isA<MalformedSettingsFileException>());
    expect(error, isNot(isA<FormatException>()));
    expect(error.toString(), contains(fixture.path));
    expect(error.toString(), contains('Fix or remove'));
    expect(await file.readAsString(), raw);
  });

  test('reviewer ID is generated once and persisted', () async {
    final repo = await newFileSettingsStore();

    final first = await repo.getOrCreateReviewReviewerId();
    final second = await repo.getOrCreateReviewReviewerId();

    expect(first, startsWith('local-reviewer-'));
    expect(second, first);
  });

  test('reviewer ID is generated once for concurrent calls', () async {
    final repo = await newFileSettingsStore();

    final ids = await Future.wait([
      repo.getOrCreateReviewReviewerId(),
      repo.getOrCreateReviewReviewerId(),
    ]);

    expect(ids.first, startsWith('local-reviewer-'));
    expect(ids.toSet(), hasLength(1));
  });

  test('reviewer alias is optional and trimmed', () async {
    final repo = await newFileSettingsStore();

    expect(await repo.getReviewReviewerAlias(), isNull);
    await repo.setReviewReviewerAlias('  Local Reviewer  ');
    expect(await repo.getReviewReviewerAlias(), 'Local Reviewer');
    await repo.setReviewReviewerAlias('   ');
    expect(await repo.getReviewReviewerAlias(), isNull);
  });

  group('custom local providers', () {
    test('getCustomLocalProviders returns empty when no data', () async {
      final repo = await newFileSettingsStore();
      expect(await repo.getCustomLocalProviders(), isEmpty);
    });

    test('setCustomLocalProviders roundtrips', () async {
      final repo = await newFileSettingsStore();
      await repo.setCustomLocalProviders([
        const CustomLocalProviderEntry(id: 'test_id', name: 'Test'),
      ]);
      final result = await repo.getCustomLocalProviders();
      expect(result.length, 1);
      expect(result.first.id, 'test_id');
      expect(result.first.name, 'Test');
    });

    test(
      'setCustomLocalProviders stores extraHeaders and defaultEfforts',
      () async {
        final repo = await newFileSettingsStore();
        await repo.setCustomLocalProviders(const [
          CustomLocalProviderEntry(
            id: 'with_headers',
            name: 'H',
            extraHeaders: {'X-Foo': 'bar'},
            defaultEfforts: ['low', 'medium'],
          ),
        ]);
        final result = await repo.getCustomLocalProviders();
        expect(result.first.extraHeaders, {'X-Foo': 'bar'});
        expect(result.first.defaultEfforts, ['low', 'medium']);
      },
    );

    test('setCustomLocalProviders trims fields', () async {
      final repo = await newFileSettingsStore();
      await repo.setCustomLocalProviders(const [
        CustomLocalProviderEntry(
          id: '  test_id  ',
          name: '  Test  ',
          extraHeaders: {'  X-Foo  ': '  bar  '},
          defaultEfforts: ['  low  ', '  medium  ', ''],
        ),
      ]);
      final result = await repo.getCustomLocalProviders();
      expect(result.first.id, 'test_id');
      expect(result.first.name, 'Test');
      expect(result.first.extraHeaders['X-Foo'], 'bar');
      expect(result.first.defaultEfforts, ['low', 'medium']);
    });

    test('setCustomLocalProviders rejects reserved IDs', () async {
      final repo = await newFileSettingsStore();
      for (final id in customLocalProviderReservedIds) {
        await expectLater(
          () => repo.setCustomLocalProviders([
            CustomLocalProviderEntry(id: id, name: 'n'),
          ]),
          throwsArgumentError,
        );
      }
    });

    test('setCustomLocalProviders rejects duplicate IDs', () async {
      final repo = await newFileSettingsStore();
      await expectLater(
        () => repo.setCustomLocalProviders(const [
          CustomLocalProviderEntry(id: 'dup', name: 'A'),
          CustomLocalProviderEntry(id: 'dup', name: 'B'),
        ]),
        throwsArgumentError,
      );
    });

    test('setCustomLocalProviders rejects empty name after trim', () async {
      final repo = await newFileSettingsStore();
      await expectLater(
        () => repo.setCustomLocalProviders(const [
          CustomLocalProviderEntry(id: 'abc', name: '   '),
        ]),
        throwsArgumentError,
      );
    });

    test('setCustomLocalProviders rejects invalid slug', () async {
      final repo = await newFileSettingsStore();
      await expectLater(
        () => repo.setCustomLocalProviders(const [
          CustomLocalProviderEntry(id: 'AB', name: 'Bad'),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        () => repo.setCustomLocalProviders(const [
          CustomLocalProviderEntry(id: 'a', name: 'Too short'),
        ]),
        throwsArgumentError,
      );
    });

    test('migration seeds local_openai when legacy keys exist', () async {
      final repo = await newFileSettingsStore();
      await repo.setBaseUrlOverride('local_openai', 'http://localhost:8080/v1');
      await repo.setApiKey('local_openai', 'sk-test');
      final result = await repo.getCustomLocalProviders();
      expect(result.length, 1);
      expect(result.first.id, 'local_openai');
      expect(result.first.name, 'Local OpenAI');
    });

    test('migration seeds local_openai when only legacy key exists', () async {
      final repo = await newFileSettingsStore();
      await repo.setApiKey('local_openai', 'sk-test');
      final result = await repo.getCustomLocalProviders();
      expect(result.length, 1);
      expect(result.first.id, 'local_openai');
      final url = await repo.getBaseUrlOverride('local_openai');
      expect(url, 'http://127.0.0.1:8080/v1');
    });

    test('migration seeds local_openai when default env key exists', () async {
      final repo = await newFileSettingsStore(
        environment: const {'DART_ARENA_API_KEY_LOCAL_OPENAI': 'env-key'},
      );

      final result = await repo.getCustomLocalProviders();

      expect(result.length, 1);
      expect(result.first.id, 'local_openai');
      expect(await repo.getApiKey('local_openai'), 'env-key');
      expect(
        await repo.getBaseUrlOverride('local_openai'),
        'http://127.0.0.1:8080/v1',
      );
    });

    test('migration seeds local_openai when apiKeyEnv key exists', () async {
      final fixture = await newSettingsFilePath();
      await File(fixture.path).writeAsString(
        jsonEncode({
          'providers': {
            'local_openai': {'apiKeyEnv': 'LOCAL_OPENAI_KEY'},
          },
        }),
      );
      final repo = FileSettingsStore(
        path: fixture.path,
        environment: const {'LOCAL_OPENAI_KEY': 'env-key'},
      );

      final result = await repo.getCustomLocalProviders();

      expect(result.length, 1);
      expect(result.first.id, 'local_openai');
      expect(await repo.getApiKey('local_openai'), 'env-key');
      expect(
        await repo.getBaseUrlOverride('local_openai'),
        'http://127.0.0.1:8080/v1',
      );
    });

    test(
      'migration does not seed when legacy keys are empty/whitespace',
      () async {
        final repo = await newFileSettingsStore();
        await repo.setBaseUrlOverride('local_openai', '   ');
        final result = await repo.getCustomLocalProviders();
        expect(result, isEmpty);
      },
    );

    test('migration does not seed when legacy keys are absent', () async {
      final repo = await newFileSettingsStore();
      final result = await repo.getCustomLocalProviders();
      expect(result, isEmpty);
    });

    test('migration trims legacy URL before storing', () async {
      final repo = await newFileSettingsStore();
      await repo.setBaseUrlOverride('local_openai', ' http://foo.com/v1 ');
      await repo.getCustomLocalProviders();
      final url = await repo.getBaseUrlOverride('local_openai');
      expect(url, 'http://foo.com/v1');
    });

    test('malformed index JSON returns empty list', () async {
      final fixture = await newSettingsFilePath();
      await File(
        fixture.path,
      ).writeAsString(jsonEncode({'customLocalProviders': 'not-json'}));
      final repo = FileSettingsStore(path: fixture.path, environment: const {});
      final result = await repo.getCustomLocalProviders();
      expect(result, isEmpty);
    });

    test('deleteCustomLocalProvider clears API key and base URL', () async {
      final repo = await newFileSettingsStore();
      await repo.setApiKey('test_id', 'sk');
      await repo.setBaseUrlOverride('test_id', 'http://localhost');
      await repo.setCustomLocalProviders([
        const CustomLocalProviderEntry(id: 'test_id', name: 'Test'),
      ]);

      await repo.deleteCustomLocalProvider('test_id');

      final list = await repo.getCustomLocalProviders();
      expect(list, isEmpty);
      expect(await repo.getApiKey('test_id'), isNull);
      expect(await repo.getBaseUrlOverride('test_id'), isNull);
    });

    test('deleteCustomLocalProvider is idempotent', () async {
      final repo = await newFileSettingsStore();
      await repo.deleteCustomLocalProvider('nonexistent');
    });

    test(
      'setCustomLocalProviders does not clear secrets for removed entries',
      () async {
        final repo = await newFileSettingsStore();
        await repo.setApiKey('old_id', 'sk');
        await repo.setBaseUrlOverride('old_id', 'http://old');
        await repo.setCustomLocalProviders([
          const CustomLocalProviderEntry(id: 'old_id', name: 'Old'),
        ]);

        await repo.setCustomLocalProviders([
          const CustomLocalProviderEntry(id: 'new_id', name: 'New'),
        ]);

        expect(await repo.getApiKey('old_id'), 'sk');
        expect(await repo.getBaseUrlOverride('old_id'), 'http://old');
      },
    );

    test('ID validation rejects reserved IDs', () {
      expect(
        validateCustomLocalProviderId('openai', existingIds: const []),
        isNotNull,
      );
    });

    test('ID validation rejects too short ID', () {
      expect(
        validateCustomLocalProviderId('a', existingIds: const []),
        isNotNull,
      );
    });

    test('ID validation rejects uppercase', () {
      expect(
        validateCustomLocalProviderId('Foo', existingIds: const []),
        isNotNull,
      );
    });

    test('ID validation rejects duplicate', () {
      expect(
        validateCustomLocalProviderId('abc', existingIds: ['abc']),
        isNotNull,
      );
    });

    test('ID validation accepts duplicate for edit mode (currentId)', () {
      expect(
        validateCustomLocalProviderId(
          'abc',
          existingIds: ['abc'],
          currentId: 'abc',
        ),
        isNull,
      );
    });

    test('ID validation accepts local_openai', () {
      expect(
        validateCustomLocalProviderId('local_openai', existingIds: const []),
        isNull,
      );
    });

    test('entry validation rejects blank display name', () {
      expect(
        validateCustomLocalProviderEntry(
          const CustomLocalProviderEntry(id: 'abc', name: '   '),
          existingIds: const [],
        ),
        isNotNull,
      );
    });
  });
}
