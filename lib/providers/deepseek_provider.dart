import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class DeepSeekProvider extends OpenAiCompatibleProvider {
  DeepSeekProvider({required String apiKey, Dio? dio})
      : super(
          dio,
          id: 'deepseek',
          displayName: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com/v1',
          apiKey: apiKey,
        );
}
