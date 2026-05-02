import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class OpenRouterProvider extends OpenAiCompatibleProvider {
  OpenRouterProvider({required String apiKey, Dio? dio})
      : super(
          dio,
          id: 'openrouter',
          displayName: 'OpenRouter',
          baseUrl: 'https://openrouter.ai/api/v1',
          apiKey: apiKey,
          extraHeaders: const <String, String>{
            'X-Title': 'dart_arena',
          },
        );
}
