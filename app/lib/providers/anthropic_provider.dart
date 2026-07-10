import 'package:dart_arena/core/model_response.dart';
import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/model_stream_event.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class AnthropicProvider
    implements StreamingModelProvider, ModelRuntimeMetadataProvider {
  AnthropicProvider({required this.apiKey, Dio? dio})
    : _dio = dio ?? (Dio()..interceptors.add(PrettyDioLogger()));

  @override
  String get id => 'anthropic';
  @override
  String get displayName => 'Anthropic';
  @override
  ProviderMode get mode => ProviderMode.rawApi;

  static const String baseUrl = 'https://api.anthropic.com/v1';
  static const int _maxOutputTokens = 4096;
  static const String _anthropicVersion = '2023-06-01';
  final String apiKey;
  final Dio _dio;

  @override
  Map<String, Object?> providerRuntimeConfig() => {
    'providerMode': mode.name,
    'requestProtocol': 'anthropic_messages',
    'anthropicVersion': _anthropicVersion,
  };

  @override
  Map<String, Object?> modelRuntimeConfig(String modelId) => const {
    'maxOutputTokens': _maxOutputTokens,
    'temperature': {'configured': false, 'status': 'provider_default'},
    'toolPolicy': 'none',
  };

  @override
  void dispose() => _dio.close(force: true);

  Map<String, String> _headers() => <String, String>{
    'x-api-key': apiKey,
    'anthropic-version': _anthropicVersion,
    'Content-Type': 'application/json',
  };

  @override
  Future<List<ModelInfo>> listModels() async => const [
    ModelInfo(id: 'claude-opus-4-5'),
    ModelInfo(id: 'claude-sonnet-4-5'),
    ModelInfo(id: 'claude-haiku-4-5'),
    ModelInfo(id: 'claude-3-5-haiku'),
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
        'max_tokens': _maxOutputTokens,
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
    final usage =
        data['usage'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return ModelResponse(
      rawText: text,
      extractedCode: null,
      promptTokens: usage['input_tokens'] as int?,
      completionTokens: usage['output_tokens'] as int?,
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
    final response = await generate(
      prompt: prompt,
      model: model,
      timeout: timeout,
    );
    if (response.rawText.isNotEmpty) {
      yield ModelStreamContentDelta(response.rawText);
    }
    yield ModelStreamUsage(
      promptTokens: response.promptTokens,
      completionTokens: response.completionTokens,
    );
    yield const ModelStreamCompleted();
  }
}
