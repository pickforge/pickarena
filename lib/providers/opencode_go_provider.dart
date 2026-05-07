import 'package:dart_arena/providers/model_provider.dart';
import 'package:dart_arena/providers/openai_compatible_provider.dart';
import 'package:dio/dio.dart';

class OpenCodeGoProvider extends OpenAiCompatibleProvider {
  OpenCodeGoProvider({required String apiKey, Dio? dio})
    : super(
        dio,
        id: 'opencode_go',
        displayName: 'OpenCode Go',
        baseUrl: 'https://opencode.ai/zen/go/v1',
        apiKey: apiKey,
        defaultEfforts: const ['low', 'medium', 'high', 'max'],
      );

  /// Return only models routed through /chat/completions.
  /// Go also proxies Claude via /v1/messages and GPT-5 via /v1/responses.
  @override
  Future<List<ModelInfo>> listModels() async {
    try {
      final all = await super.listModels();
      if (all.isEmpty) return _chatModelInfos;
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
          .where(
            (info) => chatCompatiblePrefixes.any((p) => info.id.startsWith(p)),
          )
          .toList();
      return filtered.isNotEmpty ? filtered : _chatModelInfos;
    } catch (_) {
      return _chatModelInfos;
    }
  }

  List<ModelInfo> get _chatModelInfos => _chatModels
      .map((id) => ModelInfo(id: id, efforts: defaultEfforts))
      .toList();

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
