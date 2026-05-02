import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _ConcreteProvider extends OpenAiCompatibleProvider {
  _ConcreteProvider(super.dio)
      : super(
          id: 'test',
          displayName: 'Test',
          baseUrl: 'https://test.example/v1',
          apiKey: 'sk-x',
        );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<String, dynamic>{});
  });

  test('generate posts to /chat/completions and parses content+usage',
      () async {
    final dio = _MockDio();
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: <String, dynamic>{
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'hello'},
              },
            ],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 3},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final p = _ConcreteProvider(dio);
    final r = await p.generate(prompt: 'hi', model: 'm');

    expect(r.rawText, 'hello');
    expect(r.promptTokens, 10);
    expect(r.completionTokens, 3);
  });

  test('listModels parses /models response', () async {
    final dio = _MockDio();
    when(() => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        )).thenAnswer((_) async => Response(
          data: <String, dynamic>{
            'data': [
              {'id': 'model-a'},
              {'id': 'model-b'},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ));

    final p = _ConcreteProvider(dio);
    expect(await p.listModels(), ['model-a', 'model-b']);
  });
}
