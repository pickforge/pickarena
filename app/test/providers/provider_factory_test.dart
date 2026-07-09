import 'package:dart_arena/providers/provider_factory.dart';
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dart_arena/storage/settings_store.dart';
import 'package:test/test.dart';

import '../support/settings_store_test_utils.dart';

void main() {
  test('Ollama Local + Droid are always enabled', () async {
    final providers = await buildEnabledProviders(await newFileSettingsStore());
    final ids = providers.map((p) => p.id).toList();
    expect(ids, containsAll(['ollama_local', 'droid']));
  });

  test('cloud providers appear once their key is set', () async {
    final repo = await newFileSettingsStore();
    expect(
      (await buildEnabledProviders(repo)).any((p) => p.id == 'opencode_go'),
      isFalse,
    );
    await repo.setApiKey('opencode_go', 'sk');
    expect(
      (await buildEnabledProviders(repo)).any((p) => p.id == 'opencode_go'),
      isTrue,
    );
  });

  test('OpenCode Go accepts legacy OpenCode Zen key slot', () async {
    final repo = await newFileSettingsStore();
    await repo.setApiKey('opencode_zen', 'legacy-sk');
    final provider = (await buildEnabledProviders(
      repo,
    )).singleWhere((p) => p.id == 'opencode_go');
    expect(provider.displayName, 'OpenCode Go');
  });

  test('no cloud providers appear with empty keys', () async {
    final providers = await buildEnabledProviders(await newFileSettingsStore());
    final ids = providers.map((p) => p.id).toSet();
    expect(ids, containsAll(['ollama_local', 'droid']));
    expect(ids.contains('openai'), isFalse);
    expect(ids.contains('anthropic'), isFalse);
  });

  test(
    'local OpenAI-compatible provider uses default and override settings',
    () async {
      final repo = await newFileSettingsStore();
      await repo.setBaseUrlOverride('local_openai', 'http://127.0.0.1:8080/v1');
      var provider = (await buildEnabledProviders(repo))
          .whereType<OpenAiCompatibleProvider>()
          .singleWhere((p) => p.id == 'local_openai');
      expect(provider.baseUrl, 'http://127.0.0.1:8080/v1');
      expect(provider.apiKey, '');

      await repo.setBaseUrlOverride('local_openai', 'http://127.0.0.1:9000/v1');
      await repo.setApiKey('local_openai', 'local-key');
      provider = (await buildEnabledProviders(repo))
          .whereType<OpenAiCompatibleProvider>()
          .singleWhere((p) => p.id == 'local_openai');
      expect(provider.baseUrl, 'http://127.0.0.1:9000/v1');
      expect(provider.apiKey, 'local-key');
    },
  );

  test('local_openai has empty default efforts', () async {
    final repo = await newFileSettingsStore();
    await repo.setBaseUrlOverride('local_openai', 'http://127.0.0.1:8080/v1');
    final providers = await buildEnabledProviders(repo);
    final local = providers.whereType<OpenAiCompatibleProvider>().singleWhere(
      (p) => p.id == 'local_openai',
    );
    expect(local.defaultEfforts, isEmpty);
  });

  test('env-backed local_openai migration enables provider', () async {
    final repo = await newFileSettingsStore(
      environment: const {'DART_ARENA_API_KEY_LOCAL_OPENAI': 'env-key'},
    );

    final providers = await buildEnabledProviders(repo);

    final local = providers.whereType<OpenAiCompatibleProvider>().singleWhere(
      (p) => p.id == 'local_openai',
    );
    expect(local.baseUrl, 'http://127.0.0.1:8080/v1');
    expect(local.apiKey, 'env-key');
  });

  test(
    'enabled cloud OpenAI-compatible providers have expected effort lists',
    () async {
      final repo = await newFileSettingsStore();
      await repo.setApiKey('deepseek', 'sk');
      await repo.setApiKey('openai', 'sk');
      await repo.setApiKey('openrouter', 'sk');
      final providers = await buildEnabledProviders(repo);

      final deepseek = providers
          .whereType<OpenAiCompatibleProvider>()
          .singleWhere((p) => p.id == 'deepseek');
      expect(deepseek.defaultEfforts, ['high', 'max']);

      final openai = providers
          .whereType<OpenAiCompatibleProvider>()
          .singleWhere((p) => p.id == 'openai');
      expect(openai.defaultEfforts, ['low', 'medium', 'high', 'xhigh']);

      final openrouter = providers
          .whereType<OpenAiCompatibleProvider>()
          .singleWhere((p) => p.id == 'openrouter');
      expect(openrouter.defaultEfforts, ['low', 'medium', 'high', 'max']);
    },
  );

  test('custom providers appear when URLs are configured', () async {
    final repo = await newFileSettingsStore();
    await repo.setBaseUrlOverride('codex', 'http://127.0.0.1:9000/v1');
    await repo.setApiKey('codex', 'sk-codex');
    await repo.setBaseUrlOverride('qwen', 'http://127.0.0.1:9001/v1');
    await repo.setCustomLocalProviders([
      const CustomLocalProviderEntry(
        id: 'codex',
        name: 'Codex',
        extraHeaders: {'X-Custom': 'v'},
        defaultEfforts: ['low', 'high'],
      ),
      const CustomLocalProviderEntry(id: 'qwen', name: 'Qwen'),
    ]);
    final providers = await buildEnabledProviders(repo);
    final customs = providers
        .whereType<OpenAiCompatibleProvider>()
        .where((p) => p.id == 'codex' || p.id == 'qwen')
        .toList();
    expect(customs.length, 2);
    expect(customs[0].id, 'codex');
    expect(customs[0].displayName, 'Codex');
    expect(customs[0].defaultEfforts, ['low', 'high']);
    expect(customs[0].extraHeaders, {'X-Custom': 'v'});
    expect(customs[1].id, 'qwen');
    expect(customs[1].displayName, 'Qwen');
  });

  test('custom providers without URL are skipped', () async {
    final repo = await newFileSettingsStore();
    await repo.setCustomLocalProviders([
      const CustomLocalProviderEntry(id: 'nosetup', name: 'No Setup'),
    ]);
    final providers = await buildEnabledProviders(repo);
    expect(providers.any((p) => p.id == 'nosetup'), isFalse);
  });

  test('custom providers with whitespace-only URL are skipped', () async {
    final repo = await newFileSettingsStore();
    await repo.setBaseUrlOverride('blank', '   ');
    await repo.setCustomLocalProviders([
      const CustomLocalProviderEntry(id: 'blank', name: 'Blank'),
    ]);
    final providers = await buildEnabledProviders(repo);
    expect(providers.any((p) => p.id == 'blank'), isFalse);
  });

  test(
    'local_openai is not present without legacy settings or custom entry',
    () async {
      final providers = await buildEnabledProviders(
        await newFileSettingsStore(),
      );
      expect(providers.any((p) => p.id == 'local_openai'), isFalse);
    },
  );
}
