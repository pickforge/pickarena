import 'package:dart_arena/storage/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('default Ollama URL is localhost:11434', () async {
    final repo = SettingsRepository();
    expect(await repo.getOllamaBaseUrl(), 'http://localhost:11434');
  });

  test('setOllamaBaseUrl roundtrips', () async {
    final repo = SettingsRepository();
    await repo.setOllamaBaseUrl('http://example.com:11434');
    expect(await repo.getOllamaBaseUrl(), 'http://example.com:11434');
  });

  test('per-provider api keys roundtrip', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    expect(await repo.getApiKey('opencode_go'), isNull);
    await repo.setApiKey('opencode_go', 'sk-go-1');
    expect(await repo.getApiKey('opencode_go'), 'sk-go-1');
    await repo.clearApiKey('opencode_go');
    expect(await repo.getApiKey('opencode_go'), isNull);
  });

  test('ollama cloud key has its own slot', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    await repo.setApiKey('ollama_cloud', 'cloud-token');
    expect(await repo.getApiKey('ollama_cloud'), 'cloud-token');
  });

  test('base URL override roundtrips', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
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

  test('run concurrency defaults to 4', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    expect(await repo.getRunConcurrency(), 4);
  });

  test('run concurrency roundtrips', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    await repo.setRunConcurrency(7);
    expect(await repo.getRunConcurrency(), 7);
  });

  test('run concurrency clamps low values', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    await repo.setRunConcurrency(0);
    expect(await repo.getRunConcurrency(), 1);
  });

  test('run concurrency clamps high values', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();
    await repo.setRunConcurrency(100);
    expect(await repo.getRunConcurrency(), 8);
  });

  test('run concurrency falls back for invalid stored value', () async {
    FlutterSecureStorage.setMockInitialValues({'run_concurrency': 'abc'});
    final repo = SettingsRepository();
    expect(await repo.getRunConcurrency(), 4);
  });

  test('reviewer ID is generated once and persisted', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();

    final first = await repo.getOrCreateReviewReviewerId();
    final second = await repo.getOrCreateReviewReviewerId();

    expect(first, startsWith('local-reviewer-'));
    expect(second, first);
  });

  test('reviewer alias is optional and trimmed', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final repo = SettingsRepository();

    expect(await repo.getReviewReviewerAlias(), isNull);
    await repo.setReviewReviewerAlias('  Local Reviewer  ');
    expect(await repo.getReviewReviewerAlias(), 'Local Reviewer');
    await repo.setReviewReviewerAlias('   ');
    expect(await repo.getReviewReviewerAlias(), isNull);
  });

  group('custom local providers', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('getCustomLocalProviders returns empty when no data', () async {
      final repo = SettingsRepository();
      expect(await repo.getCustomLocalProviders(), isEmpty);
    });

    test('setCustomLocalProviders roundtrips', () async {
      final repo = SettingsRepository();
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
        final repo = SettingsRepository();
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
      final repo = SettingsRepository();
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
      final repo = SettingsRepository();
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
      final repo = SettingsRepository();
      await expectLater(
        () => repo.setCustomLocalProviders(const [
          CustomLocalProviderEntry(id: 'dup', name: 'A'),
          CustomLocalProviderEntry(id: 'dup', name: 'B'),
        ]),
        throwsArgumentError,
      );
    });

    test('setCustomLocalProviders rejects empty name after trim', () async {
      final repo = SettingsRepository();
      await expectLater(
        () => repo.setCustomLocalProviders(const [
          CustomLocalProviderEntry(id: 'abc', name: '   '),
        ]),
        throwsArgumentError,
      );
    });

    test('setCustomLocalProviders rejects invalid slug', () async {
      final repo = SettingsRepository();
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
      FlutterSecureStorage.setMockInitialValues({
        'base_url:local_openai': 'http://localhost:8080/v1',
        'api_key:local_openai': 'sk-test',
      });
      final repo = SettingsRepository();
      final result = await repo.getCustomLocalProviders();
      expect(result.length, 1);
      expect(result.first.id, 'local_openai');
      expect(result.first.name, 'Local OpenAI');
    });

    test('migration seeds local_openai when only legacy key exists', () async {
      FlutterSecureStorage.setMockInitialValues({
        'api_key:local_openai': 'sk-test',
      });
      final repo = SettingsRepository();
      final result = await repo.getCustomLocalProviders();
      expect(result.length, 1);
      expect(result.first.id, 'local_openai');
      // Should also write the default base URL
      final url = await repo.getBaseUrlOverride('local_openai');
      expect(url, 'http://127.0.0.1:8080/v1');
    });

    test(
      'migration does not seed when legacy keys are empty/whitespace',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'base_url:local_openai': '   ',
        });
        final repo = SettingsRepository();
        final result = await repo.getCustomLocalProviders();
        expect(result, isEmpty);
      },
    );

    test('migration does not seed when legacy keys are absent', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final repo = SettingsRepository();
      final result = await repo.getCustomLocalProviders();
      expect(result, isEmpty);
    });

    test('migration trims legacy URL before storing', () async {
      FlutterSecureStorage.setMockInitialValues({
        'base_url:local_openai': ' http://foo.com/v1 ',
      });
      final repo = SettingsRepository();
      await repo.getCustomLocalProviders();
      final url = await repo.getBaseUrlOverride('local_openai');
      expect(url, 'http://foo.com/v1');
    });

    test('malformed index JSON returns empty list', () async {
      FlutterSecureStorage.setMockInitialValues({
        'custom_local_providers': 'not-json',
      });
      final repo = SettingsRepository();
      final result = await repo.getCustomLocalProviders();
      expect(result, isEmpty);
    });

    test('deleteCustomLocalProvider clears API key and base URL', () async {
      final repo = SettingsRepository();
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
      final repo = SettingsRepository();
      await repo.deleteCustomLocalProvider('nonexistent');
      // Should not throw
    });

    test(
      'setCustomLocalProviders does not clear secrets for removed entries',
      () async {
        final repo = SettingsRepository();
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
