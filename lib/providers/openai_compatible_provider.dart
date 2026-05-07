import 'dart:convert';

import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class OpenAiCompatibleProvider implements StreamingModelProvider {
  OpenAiCompatibleProvider(
    Dio? dio, {
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.apiKey,
    this.extraHeaders = const <String, String>{},
    this.defaultEfforts = const [],
  }) : _dio = dio ?? (Dio()..interceptors.add(PrettyDioLogger()));

  @override
  final String id;
  @override
  final String displayName;
  final String baseUrl;
  final String apiKey;
  final Map<String, String> extraHeaders;
  final List<String> defaultEfforts;
  final Dio _dio;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  Map<String, String> _headers() => <String, String>{
    if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
    ...extraHeaders,
  };

  ({String baseModel, String? effort}) _parseEffort(String model) {
    final idx = model.lastIndexOf('::');
    if (idx == -1) return (baseModel: model, effort: null);
    final suffix = model.substring(idx + 2);
    if (defaultEfforts.contains(suffix)) {
      return (baseModel: model.substring(0, idx), effort: suffix);
    }
    return (baseModel: model, effort: null);
  }

  @override
  Future<List<ModelInfo>> listModels() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/models',
      options: Options(headers: _headers()),
    );
    final list = (res.data?['data'] as List<dynamic>? ?? <dynamic>[])
        .map((m) => (m as Map<String, dynamic>)['id'] as String)
        .map((id) => ModelInfo(id: id, efforts: defaultEfforts))
        .toList();
    return list;
  }

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final (:baseModel, :effort) = _parseEffort(model);
    final stopwatch = Stopwatch()..start();
    final body = <String, dynamic>{
      'model': baseModel,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'stream': false,
    };
    if (effort != null) {
      body['reasoning_effort'] = effort;
    }
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/chat/completions',
      data: body,
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
    final (:baseModel, :effort) = _parseEffort(model);
    yield const ModelStreamStarted();

    final body = <String, dynamic>{
      'model': baseModel,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'stream': true,
    };
    if (effort != null) {
      body['reasoning_effort'] = effort;
    }
    final res = await _dio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      data: body,
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
