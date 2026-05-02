import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dio/dio.dart';

class OpenAiCompatibleProvider implements ModelProvider {
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
        'Authorization': 'Bearer $apiKey',
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
            as Map<String, dynamic>? ?? const <String, dynamic>{};
    final content = message['content'] as String? ?? '';
    final usage = data['usage'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return ModelResponse(
      rawText: content,
      extractedCode: null,
      promptTokens: usage['prompt_tokens'] as int?,
      completionTokens: usage['completion_tokens'] as int?,
      latency: stopwatch.elapsed,
    );
  }
}
