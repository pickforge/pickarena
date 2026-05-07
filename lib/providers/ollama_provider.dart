import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class OllamaProvider implements ModelProvider {
  OllamaProvider({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.apiKey,
    Dio? dio,
  }) : _dio = dio ?? (Dio()..interceptors.add(PrettyDioLogger()));

  @override
  final String id;
  @override
  final String displayName;
  final String baseUrl;
  final String? apiKey;
  final Dio _dio;

  @override
  ProviderMode get mode => ProviderMode.rawApi;

  Map<String, String> _headers() => <String, String>{
    if (apiKey != null) 'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<ModelInfo>> listModels() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/api/tags',
      options: Options(headers: _headers()),
    );
    final models = (res.data?['models'] as List<dynamic>? ?? <dynamic>[])
        .map((m) => (m as Map<String, dynamic>)['name'] as String)
        .map((id) => ModelInfo(id: id))
        .toList();
    return models;
  }

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/api/generate',
      data: <String, dynamic>{
        'model': model,
        'prompt': prompt,
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
    return ModelResponse(
      rawText: (data['response'] as String?) ?? '',
      extractedCode: null,
      promptTokens: data['prompt_eval_count'] as int?,
      completionTokens: data['eval_count'] as int?,
      latency: stopwatch.elapsed,
    );
  }
}
