import 'package:dart_arena/providers/factory_custom_model_environment.dart';
import 'package:test/test.dart';

void main() {
  test('finds env references for selected custom model settings', () {
    final references = factoryCustomModelEnvironmentReferences(
      'custom:gpt-5.3-codex-spark---Codex',
      settings: const {
        'customModels': [
          {
            'id': 'custom:gpt-5.3-codex-spark---Codex',
            'model': 'gpt-5.3-codex-spark',
            'apiKey': r'${CODEX_API_KEY}',
            'headers': {'Authorization': r'Bearer $SPARK_TOKEN'},
          },
        ],
      },
    );

    expect(references, {'CODEX_API_KEY', 'SPARK_TOKEN'});
  });

  test('returns empty references for unselected or built-in models', () {
    final references = factoryCustomModelEnvironmentReferences(
      'gpt-5.5',
      settings: const {
        'customModels': [
          {
            'id': 'custom:gpt-5.3-codex-spark---Codex',
            'model': 'gpt-5.3-codex-spark',
            'apiKey': r'${CODEX_API_KEY}',
          },
        ],
      },
    );

    expect(references, isEmpty);
  });

  test('returns sanitized runtime config for selected custom model', () {
    final config = factoryCustomModelRuntimeConfig(
      'custom:gpt-5.3-codex-spark---Codex',
      settings: const {
        'customModels': [
          {
            'id': 'custom:gpt-5.3-codex-spark---Codex',
            'model': 'gpt-5.3-codex-spark',
            'displayName': 'GPT 5.3 Codex Spark',
            'provider': 'codex',
            'maxOutputTokens': 12000,
            'maxContextLimit': 200000,
            'noImageSupport': true,
            'apiKey': r'${CODEX_API_KEY}',
            'baseUrl': 'https://private.example.invalid/v1',
            'headers': {'Authorization': r'Bearer $SPARK_TOKEN'},
          },
        ],
      },
    );

    expect(config, {
      'factoryCustomModel': true,
      'factoryCustomModelId': 'custom:gpt-5.3-codex-spark---Codex',
      'configuredModelSnapshot': 'gpt-5.3-codex-spark',
      'customModelProvider': 'codex',
      'customModelDisplayName': 'GPT 5.3 Codex Spark',
      'maxOutputTokens': 12000,
      'maxContextTokens': 200000,
      'imageInputSupported': false,
    });
    expect(config.keys, isNot(contains('apiKey')));
    expect(config.keys, isNot(contains('baseUrl')));
    expect(config.keys, isNot(contains('headers')));
  });
}
