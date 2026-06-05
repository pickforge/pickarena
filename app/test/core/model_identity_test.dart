import 'package:dart_arena/core/model_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses reasoning effort variants without changing model id', () {
    final identity = ModelIdentity.from(
      providerId: 'openai',
      modelId: 'gpt-5::high',
    );

    expect(identity.providerId, 'openai');
    expect(identity.modelId, 'gpt-5::high');
    expect(identity.baseModelId, 'gpt-5');
    expect(identity.modelConfigJson, {'effort': 'high'});
    expect(identity.exportJson, {
      'baseModelId': 'gpt-5',
      'modelConfig': {'effort': 'high'},
    });
  });

  test('keeps plain model ids as their own base model', () {
    final identity = ModelIdentity.from(providerId: 'openai', modelId: 'gpt-5');

    expect(identity.baseModelId, 'gpt-5');
    expect(identity.modelConfigJson, isEmpty);
  });

  test('merges and sorts additional public model config metadata', () {
    final identity = ModelIdentity.from(
      providerId: 'openai',
      modelId: 'gpt-5::high',
      additionalModelConfig: const {
        'retryPolicy': {
          'retryStatusCodes': [429],
          'maxRetries': 3,
        },
        'maxOutputTokens': 16384,
        'temperature': {'configured': false, 'status': 'provider_default'},
        'empty': '',
        'effort': 'low',
      },
    );

    expect(identity.modelConfigJson, {
      'effort': 'high',
      'maxOutputTokens': 16384,
      'retryPolicy': {
        'maxRetries': 3,
        'retryStatusCodes': [429],
      },
      'temperature': {'configured': false, 'status': 'provider_default'},
    });
  });

  test('builds model config index from run provenance', () {
    final index = ModelConfigIndex.fromRunProvenanceJson('''
      {
        "providers": [
          {
            "id": "droid",
            "selectedModelConfigs": [
              {
                "modelId": "custom:spark",
                "baseModelId": "custom:spark",
                "modelConfig": {
                  "factoryCustomModel": true,
                  "configuredModelSnapshot": "gpt-5.3-codex-spark",
                  "toolsEnabled": false
                }
              }
            ]
          }
        ]
      }
      ''');

    expect(index.exportJsonFor(providerId: 'droid', modelId: 'custom:spark'), {
      'baseModelId': 'custom:spark',
      'modelConfig': {
        'configuredModelSnapshot': 'gpt-5.3-codex-spark',
        'factoryCustomModel': true,
        'toolsEnabled': false,
      },
    });
    expect(index.warningMessages, isEmpty);
  });

  test('drops conflicting model config metadata from public export', () {
    final index = ModelConfigIndex.fromRunProvenanceJsons([
      '{"providers":[{"id":"openai","selectedModelConfigs":[{"modelId":"gpt-5","modelConfig":{"maxOutputTokens":4096}}]}]}',
      '{"providers":[{"id":"openai","selectedModelConfigs":[{"modelId":"gpt-5","modelConfig":{"maxOutputTokens":8192}}]}]}',
    ]);

    expect(index.exportJsonFor(providerId: 'openai', modelId: 'gpt-5'), {
      'baseModelId': 'gpt-5',
      'modelConfig': <String, Object?>{},
    });
    expect(index.warningMessages.single, contains('openai:gpt-5'));
  });
}
