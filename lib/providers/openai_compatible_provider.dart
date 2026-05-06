import 'dart:convert';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dio/dio.dart';

class OpenAiCompatibleProvider implements StreamingModelProvider {
  OpenAiCompatibleProvider(
    Dio? dio, {
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.apiKey,
    this.extraHeaders = const <String, String>{},
  }) : _dio = dio ?? Dio();

  @override
  final String id;
  @override
  final String displayName;
  final String baseUrl;
  final String apiKey;
  final Map<String, String> extraHeaders;
  final Dio _dio;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  Map<String, String> _headers() => <String, String>{
    if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    ...extraHeaders,
  };

  @override
  Future<List<String>> listModels() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/models',
      options: Options(headers: _headers()),
    );
    final list = (res.data?['data'] as List<dynamic>? ?? <dynamic>[])
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .toList();
    return list;
  }

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/chat/completions',
      data: <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'stream': false,
      },
      options: Options(
        headers: _headers(),
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    stopwatch.stop();

    final data = res.data ?? const <String, dynamic>{};
    final choices = data['choices'] as List<dynamic>? ?? const <dynamic>[];
    final message = choices.isEmpty
        ? const <String, dynamic>{}
        : (choices.first as Map<String, dynamic>)['message']
                  as Map<String, dynamic>? ??
              const <String, dynamic>{};
    final content = message['content'] as String? ?? '';
    final usage =
        data['usage'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return ModelResponse(
      rawText: content,
      extractedCode: null,
      promptTokens: usage['prompt_tokens'] as int?,
      completionTokens: usage['completion_tokens'] as int?,
      latency: stopwatch.elapsed,
    );
  }

  @override
  Stream<ModelStreamEvent> generateStream({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async* {
    yield const ModelStreamStarted();

    final res = await _dio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      data: <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'stream': true,
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: _headers(),
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    final stream = res.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith(':')) continue;

      var data = trimmed;
      const prefix = 'data: ';
      if (data.startsWith(prefix)) {
        data = data.substring(prefix.length);
      } else if (data.startsWith('data:')) {
        data = data.substring('data:'.length);
      }

      if (data == '[DONE]') break;

      Map<String, dynamic> json;
      try {
        json = jsonDecode(data) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final choices = json['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final delta = choices.first['delta'] as Map<String, dynamic>?;
        if (delta != null) {
          final reasoning = delta['reasoning_content'] as String?;
          if (reasoning != null && reasoning.isNotEmpty) {
            yield ModelStreamReasoningDelta(reasoning);
          }
          final content = delta['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield ModelStreamContentDelta(content);
          }
        }
      }

      final usage = json['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        yield ModelStreamUsage(
          promptTokens: usage['prompt_tokens'] as int?,
          completionTokens: usage['completion_tokens'] as int?,
        );
      }
    }

    yield const ModelStreamCompleted();
  }
}
