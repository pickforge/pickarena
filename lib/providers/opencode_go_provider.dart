import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class OpenCodeGoProvider extends OpenAiCompatibleProvider {
  OpenCodeGoProvider({required String apiKey, Dio? dio})
    : super(
        dio,
        id: 'opencode_go',
        displayName: 'OpenCode Go',
        baseUrl: 'https://opencode.ai/go/v1',
        apiKey: apiKey,
      );

  /// Return only models routed through /chat/completions.
  /// Go also proxies Claude via /v1/messages and GPT-5 via /v1/responses.
  @override
  Future<List<String>> listModels() async {
    try {
      final all = await super.listModels();
      if (all.isEmpty) return _chatModels;
      final chatCompatiblePrefixes = [
        'qwen',
        'minimax',
        'glm',
        'kimi',
        'big-pickle',
        'ling-',
        'hy3',
        'nemotron',
      ];
      final filtered = all
          .where((id) => chatCompatiblePrefixes.any((p) => id.startsWith(p)))
          .toList();
      return filtered.isNotEmpty ? filtered : _chatModels;
    } catch (_) {
      return _chatModels;
    }
  }

  static const _chatModels = <String>[
    'qwen3.6-plus',
    'qwen3.5-plus',
    'minimax-m2.7',
    'minimax-m2.5',
    'minimax-m2.5-free',
    'glm-5.1',
    'glm-5',
    'kimi-k2.6',
    'kimi-k2.5',
    'big-pickle',
    'ling-2.6-flash',
    'hy3-preview-free',
    'nemotron-3-super-free',
  ];
}
