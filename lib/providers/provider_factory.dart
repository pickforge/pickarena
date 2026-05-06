import 'package:dart_arena/providers/anthropic_provider.dart';
import 'package:dart_arena/providers/deepseek_provider.dart';
import 'package:dart_arena/providers/droid_exec_provider.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/ollama_provider.dart';
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dart_arena/providers/openai_provider.dart';
import 'package:dart_arena/providers/opencode_go_provider.dart';
import 'package:dart_arena/providers/openrouter_provider.dart';
import 'package:dart_arena/storage/settings.dart';

Future<List<ModelProvider>> buildEnabledProviders(
  SettingsRepository repo,
) async {
  final providers = <ModelProvider>[];

  providers.add(
    OllamaProvider(
      id: 'ollama_local',
      displayName: 'Ollama Local',
      baseUrl: await repo.getOllamaBaseUrl(),
      apiKey: null,
    ),
  );

  final ollamaCloudKey = await repo.getApiKey('ollama_cloud');
  if (ollamaCloudKey != null && ollamaCloudKey.isNotEmpty) {
    providers.add(
      OllamaProvider(
        id: 'ollama_cloud',
        displayName: 'Ollama Cloud',
        baseUrl:
            await repo.getBaseUrlOverride('ollama_cloud') ??
            'https://ollama.com',
        apiKey: ollamaCloudKey,
      ),
    );
  }

  providers.add(
    OpenAiCompatibleProvider(
      null,
      id: 'local_openai',
      displayName: 'Local OpenAI-compatible',
      baseUrl:
          await repo.getBaseUrlOverride('local_openai') ??
          'http://127.0.0.1:8080/v1',
      apiKey: await repo.getApiKey('local_openai') ?? '',
    ),
  );

  Future<void> addProvider(
    String providerId,
    ModelProvider Function(String key) build,
  ) async {
    final k = await repo.getApiKey(providerId);
    if (k != null && k.isNotEmpty) providers.add(build(k));
  }

  final openCodeGoKey =
      await repo.getApiKey('opencode_go') ??
      await repo.getApiKey('opencode_zen');
  if (openCodeGoKey != null && openCodeGoKey.isNotEmpty) {
    providers.add(OpenCodeGoProvider(apiKey: openCodeGoKey));
  }
  await addProvider('openai', (k) => OpenAIProvider(apiKey: k));
  await addProvider('openrouter', (k) => OpenRouterProvider(apiKey: k));
  await addProvider('deepseek', (k) => DeepSeekProvider(apiKey: k));
  await addProvider('anthropic', (k) => AnthropicProvider(apiKey: k));

  providers.add(DroidExecProvider());

  return providers;
}
