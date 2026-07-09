import 'package:dart_arena/providers/anthropic_provider.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<String, dynamic>{});
  });

  test('runtime metadata records request defaults without secrets', () {
    final provider = AnthropicProvider(apiKey: 'sk');

    expect(provider.providerRuntimeConfig(), {
      'providerMode': 'rawApi',
      'requestProtocol': 'anthropic_messages',
      'anthropicVersion': '2023-06-01',
    });
    expect(provider.modelRuntimeConfig('claude-sonnet-4-5'), {
      'maxOutputTokens': 4096,
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolPolicy': 'none',
    });
  });

  test('generate parses Messages API response shape', () async {
    final dio = _MockDio();
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response(
        data: <String, dynamic>{
          'content': [
            {'type': 'text', 'text': 'world'},
          ],
          'usage': {'input_tokens': 5, 'output_tokens': 1},
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ),
    );

    final p = AnthropicProvider(apiKey: 'sk', dio: dio);
    final r = await p.generate(prompt: 'hi', model: 'claude-sonnet-4-5');
    expect(r.rawText, 'world');
    expect(r.promptTokens, 5);
    expect(r.completionTokens, 1);
  });

  test('listModels returns ModelInfo with curated default list', () async {
    final p = AnthropicProvider(apiKey: 'sk');
    final models = await p.listModels();
    final ids = models.map((m) => m.id).toSet();
    expect(ids, contains('claude-sonnet-4-5'));
    expect(ids, contains('claude-opus-4-5'));
    for (final m in models) {
      expect(m.efforts, isEmpty);
    }
  });
}
