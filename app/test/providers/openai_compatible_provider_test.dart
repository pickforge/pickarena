import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _ConcreteProvider extends OpenAiCompatibleProvider {
  _ConcreteProvider(super.dio, {super.apiKey = 'sk-x'})
    : super(
        id: 'test',
        displayName: 'Test',
        baseUrl: 'https://test.example/v1',
      );
}

class _ConcreteProviderWithEfforts extends OpenAiCompatibleProvider {
  _ConcreteProviderWithEfforts(super.dio, {super.apiKey = 'sk-x'})
    : super(
        id: 'test-eff',
        displayName: 'TestEff',
        baseUrl: 'https://test.example/v1',
        defaultEfforts: const ['low', 'high'],
      );
}

Stream<Uint8List> _sseLinesStream(List<String> lines) async* {
  for (final line in lines) {
    yield Uint8List.fromList(utf8.encode('$line\n'));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(<String, dynamic>{});
  });

  test('runtime metadata records request defaults without secrets', () {
    final provider = _ConcreteProviderWithEfforts(_MockDio());

    expect(provider.providerRuntimeConfig(), {
      'providerMode': 'rawApi',
      'requestProtocol': 'openai_chat_completions',
      'streamingSupported': true,
      'defaultEfforts': ['low', 'high'],
    });
    expect(provider.modelRuntimeConfig('gpt-5::high'), {
      'maxOutputTokens': 16384,
      'temperature': {'configured': false, 'status': 'provider_default'},
      'toolPolicy': 'none',
      'retryPolicy': {
        'maxRetries': 3,
        'retryStatusCodes': [429],
        'backoffSeconds': [1, 2, 4],
      },
    });
  });

  test(
    'generate posts to /chat/completions and parses content+usage',
    () async {
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
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'hello'},
              },
            ],
            'usage': {'prompt_tokens': 10, 'completion_tokens': 3},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProvider(dio);
      final r = await p.generate(prompt: 'hi', model: 'm');

      expect(r.rawText, 'hello');
      expect(r.promptTokens, 10);
      expect(r.completionTokens, 3);
    },
  );

  test(
    'listModels parses /models response and attaches defaultEfforts',
    () async {
      final dio = _MockDio();
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: <String, dynamic>{
            'data': [
              {'id': 'model-a'},
              {'id': 'model-b'},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProvider(dio);
      final models = await p.listModels();
      expect(models.map((m) => m.id), ['model-a', 'model-b']);
      for (final m in models) {
        expect(m.efforts, isEmpty);
      }
    },
  );

  test('empty api key omits Authorization header', () async {
    final dio = _MockDio();
    when(
      () =>
          dio.get<Map<String, dynamic>>(any(), options: any(named: 'options')),
    ).thenAnswer(
      (_) async => Response(
        data: const <String, dynamic>{'data': <dynamic>[]},
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ),
    );

    final p = _ConcreteProvider(dio, apiKey: '');
    await p.listModels();

    final captured =
        verify(
              () => dio.get<Map<String, dynamic>>(
                any(),
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as Options;
    expect(captured.headers, isNot(contains('Authorization')));
  });

  group('streaming', () {
    test('emits correct sequence from SSE chunks', () async {
      final dio = _MockDio();
      final responseBody = ResponseBody(
        _sseLinesStream([
          'data: {"choices":[{"delta":{"reasoning_content":"think"}}]}',
          'data: {"choices":[{"delta":{"content":"answer"}}]}',
          'data: {"usage":{"prompt_tokens":3,"completion_tokens":4},"choices":[{"delta":{},"finish_reason":"stop"}]}',
          'data: [DONE]',
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.textPlainContentType],
        },
      );

      when(
        () => dio.post<ResponseBody>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: responseBody,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProvider(dio);
      final events = await p.generateStream(prompt: 'hi', model: 'm').toList();

      expect(events.first, isA<ModelStreamStarted>());
      expect(events.last, isA<ModelStreamCompleted>());

      final reasoning = events.whereType<ModelStreamReasoningDelta>().single;
      expect(reasoning.text, 'think');

      final content = events.whereType<ModelStreamContentDelta>().single;
      expect(content.text, 'answer');

      final usage = events.whereType<ModelStreamUsage>().single;
      expect(usage.promptTokens, 3);
      expect(usage.completionTokens, 4);
    });

    test('request includes stream:true and ResponseType.stream', () async {
      final dio = _MockDio();
      final responseBody = ResponseBody(
        _sseLinesStream(['data: [DONE]']),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.textPlainContentType],
        },
      );

      when(
        () => dio.post<ResponseBody>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: responseBody,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProvider(dio);
      await p.generateStream(prompt: 'hi', model: 'm').toList();

      final captured = verify(
        () => dio.post<ResponseBody>(
          any(),
          data: captureAny(named: 'data'),
          options: captureAny(named: 'options'),
        ),
      ).captured;

      final data = captured[0] as Map<String, dynamic>;
      expect(data['stream'], true);

      final options = captured[1] as Options;
      expect(options.responseType, ResponseType.stream);
    });

    test('splits data chunks across byte boundaries', () async {
      final dio = _MockDio();

      final parts = [
        'data: {"choices":[{"delta":{"content":"'
            'he',
        'llo"}}]}\n',
      ];
      final controller = StreamController<Uint8List>();
      final responseBody = ResponseBody(
        controller.stream,
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.textPlainContentType],
        },
      );

      when(
        () => dio.post<ResponseBody>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: responseBody,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProvider(dio);
      final future = p.generateStream(prompt: 'hi', model: 'm').toList();

      for (final part in parts) {
        controller.add(Uint8List.fromList(utf8.encode(part)));
      }
      controller.add(Uint8List.fromList(utf8.encode('data: [DONE]\n')));
      await controller.close();

      final events = await future;
      final content = events.whereType<ModelStreamContentDelta>().toList();
      expect(content.length, 1);
      expect(content[0].text, 'hello');
    });

    test('handles empty choices and missing deltas gracefully', () async {
      final dio = _MockDio();
      final responseBody = ResponseBody(
        _sseLinesStream([
          'data: {"choices":[]}',
          'data: {"choices":[{}]}',
          'data: {"choices":[{"delta":null}]}',
          'data: [DONE]',
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.textPlainContentType],
        },
      );

      when(
        () => dio.post<ResponseBody>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: responseBody,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProvider(dio);
      final events = await p.generateStream(prompt: 'hi', model: 'm').toList();

      expect(events.first, isA<ModelStreamStarted>());
      expect(events.last, isA<ModelStreamCompleted>());
      expect(events.whereType<ModelStreamReasoningDelta>(), isEmpty);
      expect(events.whereType<ModelStreamContentDelta>(), isEmpty);
      expect(events.whereType<ModelStreamUsage>(), isEmpty);
    });
  });

  group('effort parsing', () {
    test('listModels attaches defaultEfforts to each model', () async {
      final dio = _MockDio();
      when(
        () => dio.get<Map<String, dynamic>>(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response(
          data: <String, dynamic>{
            'data': [
              {'id': 'm1'},
            ],
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProviderWithEfforts(dio);
      final models = await p.listModels();
      expect(models.single.id, 'm1');
      expect(models.single.efforts, ['low', 'high']);
    });

    test('generate strips ::effort and includes reasoning_effort', () async {
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
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
              },
            ],
            'usage': {'prompt_tokens': 1, 'completion_tokens': 1},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProviderWithEfforts(dio);
      await p.generate(prompt: 'hi', model: 'm1::high');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      final data = captured[0] as Map<String, dynamic>;
      expect(data['model'], 'm1');
      expect(data['reasoning_effort'], 'high');
      expect(data['stream'], false);
    });

    test(
      'generate does not include reasoning_effort for plain model',
      () async {
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
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'ok'},
                },
              ],
              'usage': {'prompt_tokens': 1, 'completion_tokens': 1},
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        );

        final p = _ConcreteProviderWithEfforts(dio);
        await p.generate(prompt: 'hi', model: 'm1');

        final captured = verify(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;

        final data = captured[0] as Map<String, dynamic>;
        expect(data['model'], 'm1');
        expect(data.containsKey('reasoning_effort'), isFalse);
      },
    );

    test('unknown suffix is not stripped', () async {
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
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
              },
            ],
            'usage': {'prompt_tokens': 1, 'completion_tokens': 1},
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      final p = _ConcreteProviderWithEfforts(dio);
      await p.generate(prompt: 'hi', model: 'm1::invalid');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          any(),
          data: captureAny(named: 'data'),
          options: any(named: 'options'),
        ),
      ).captured;

      final data = captured[0] as Map<String, dynamic>;
      expect(data['model'], 'm1::invalid');
      expect(data.containsKey('reasoning_effort'), isFalse);
    });

    test(
      'generateStream strips ::effort and includes reasoning_effort',
      () async {
        final dio = _MockDio();
        final responseBody = ResponseBody(
          _sseLinesStream(['data: [DONE]']),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.textPlainContentType],
          },
        );

        when(
          () => dio.post<ResponseBody>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: responseBody,
            statusCode: 200,
            requestOptions: RequestOptions(path: ''),
          ),
        );

        final p = _ConcreteProviderWithEfforts(dio);
        await p.generateStream(prompt: 'hi', model: 'm1::high').toList();

        final captured = verify(
          () => dio.post<ResponseBody>(
            any(),
            data: captureAny(named: 'data'),
            options: any(named: 'options'),
          ),
        ).captured;

        final data = captured[0] as Map<String, dynamic>;
        expect(data['model'], 'm1');
        expect(data['reasoning_effort'], 'high');
        expect(data['stream'], true);
      },
    );
  });
}
