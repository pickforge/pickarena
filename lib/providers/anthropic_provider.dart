import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dio/dio.dart';

class AnthropicProvider implements ModelProvider {
  AnthropicProvider({required this.apiKey, Dio? dio})
      : _dio = dio ?? Dio();

  @override
  String get id => 'anthropic';
  @override
  String get displayName => 'Anthropic';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  static const String baseUrl = 'https://api.anthropic.com/v1';
  final String apiKey;
  final Dio _dio;

  Map<String, String> _headers() => <String, String>{
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      };

  @override
  Future<List<String>> listModels() async => const [
        'claude-opus-4-5',
        'claude-sonnet-4-5',
        'claude-haiku-4-5',
        'claude-3-5-haiku',
      ];

  @override
  Future<ModelResponse> generate({
    required String prompt,
    required String model,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final res = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/messages',
      data: <String, dynamic>{
        'model': model,
        'max_tokens': 4096,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
      options: Options(
        headers: _headers(),
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    stopwatch.stop();

    final data = res.data ?? const <String, dynamic>{};
    final content = data['content'] as List<dynamic>? ?? const <dynamic>[];
    final text = content
        .whereType<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String? ?? '')
        .join();
    final usage = data['usage'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    return ModelResponse(
      rawText: text,
      extractedCode: null,
      promptTokens: usage['input_tokens'] as int?,
      completionTokens: usage['output_tokens'] as int?,
      latency: stopwatch.elapsed,
    );
  }
}
