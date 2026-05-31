import 'package:dart_arena/providers/opencode_go_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenCodeGoProvider has correct identity and base URL', () {
    final p = OpenCodeGoProvider(apiKey: 'k');
    expect(p.id, 'opencode_go');
    expect(p.displayName, 'OpenCode Go');
    expect(p.baseUrl, 'https://opencode.ai/zen/go/v1');
  });

  test('listModels returns only chat-compatible models', () async {
    final p = OpenCodeGoProvider(apiKey: 'k');
    final models = await p.listModels();
    final ids = models.map((m) => m.id).toSet();
    expect(ids, contains('qwen3.6-plus'));
    expect(ids, contains('kimi-k2.6'));
    // Should NOT include Claude models (those are /v1/messages)
    expect(ids, isNot(contains('claude-sonnet-4-5')));
  });

  test('listModels fallback models have efforts attached', () async {
    final p = OpenCodeGoProvider(apiKey: 'k');
    final models = await p.listModels();
    for (final m in models) {
      expect(m.efforts, ['low', 'medium', 'high', 'xhigh']);
    }
  });
}
