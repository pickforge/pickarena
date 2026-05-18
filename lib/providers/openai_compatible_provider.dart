import 'dart:convert';
import 'dart:developer' as developer;

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
  }) : _dio =
           dio ??
           (Dio()
             ..interceptors.addAll([
               _ErrorBodyInterceptor(),
               PrettyDioLogger(
                 requestHeader: false,
                 requestBody: false,
                 maxWidth: 120,
                 logPrint: _logFilter,
               ),
             ]));

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

  @override
  void dispose() => _dio.close(force: true);

  static void _logFilter(Object object) {
    final text = object.toString();
    if (text.contains('Instance of \'ResponseBody\'')) return;
    developer.log(text, name: 'OpenAiCompatibleProvider');
  }

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

  Future<String> _readErrorBody(DioException e) async {
    final data = e.response?.data;
    if (data is ResponseBody) {
      try {
        final bytes = await data.stream.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        return utf8.decode(bytes);
      } catch (_) {
        return '${e.message} (could not read error body)';
      }
    }
    if (data is Map) {
      return jsonEncode(data);
    }
    return data?.toString() ?? e.message ?? 'unknown error';
  }

  Future<T> _withRateLimitRetry<T>(Future<T> Function() fn) async {
    const maxRetries = 3;
    var delay = Duration.zero;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      try {
        return await fn();
      } on DioException catch (e) {
        if (e.response?.statusCode == 429 && attempt < maxRetries) {
          delay = Duration(seconds: 1 << attempt); // 1s, 2s, 4s
          continue;
        }
        rethrow;
      }
    }
    throw StateError('unreachable');
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
      'max_tokens': 16384,
    };
    if (effort != null) {
      body['reasoning_effort'] = effort;
    }
    Response<Map<String, dynamic>> res;
    try {
      res = await _withRateLimitRetry(
        () => _dio.post<Map<String, dynamic>>(
          '$baseUrl/chat/completions',
          data: body,
          options: Options(
            headers: _headers(),
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        ),
      );
    } on DioException catch (e) {
      final body = await _readErrorBody(e);
      throw DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: body,
        message: body,
      );
    }
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
      'max_tokens': 16384,
    };
    if (effort != null) {
      body['reasoning_effort'] = effort;
    }
    Response<ResponseBody> res;
    try {
      res = await _withRateLimitRetry(
        () => _dio.post<ResponseBody>(
          '$baseUrl/chat/completions',
          data: body,
          options: Options(
            responseType: ResponseType.stream,
            headers: _headers(),
            sendTimeout: timeout,
            receiveTimeout: timeout,
          ),
        ),
      );
    } on DioException catch (e) {
      final body = await _readErrorBody(e);
      throw DioException(
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
        error: body,
        message: body,
      );
    }

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

class _ErrorBodyInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final data = err.response?.data;
    if (data is ResponseBody) {
      data.stream
          .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk))
          .then((bytes) {
            err.response!.data = utf8.decode(bytes);
            handler.next(err);
          });
    } else {
      handler.next(err);
    }
  }
}
