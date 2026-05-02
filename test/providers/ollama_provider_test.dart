import 'package:dart_arena/providers/ollama_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Options());
  });

  test('generate posts to /api/generate and parses response', () async {
    final dio = _MockDio();
    when(
      () => dio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/generate'),
        statusCode: 200,
        data: const {
          'model': 'llama3',
          'response': 'hello',
          'done': true,
          'prompt_eval_count': 5,
          'eval_count': 7,
        },
      ),
    );

    final provider = OllamaProvider(
      id: 'ollama_local',
      displayName: 'Ollama Local',
      baseUrl: 'http://localhost:11434',
      apiKey: null,
      dio: dio,
    );

    final response = await provider.generate(
      prompt: 'hi',
      model: 'llama3',
    );

    expect(response.rawText, 'hello');
    expect(response.promptTokens, 5);
    expect(response.completionTokens, 7);
  });
}
