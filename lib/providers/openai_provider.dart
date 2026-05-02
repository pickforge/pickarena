import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class OpenAIProvider extends OpenAiCompatibleProvider {
  OpenAIProvider({required String apiKey, Dio? dio})
      : super(
          dio,
          id: 'openai',
          displayName: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: apiKey,
        );
}
