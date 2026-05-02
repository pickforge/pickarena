import 'package:dart_arena/providers/opencode_zen_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenCodeZenProvider has correct identity and base URL', () {
    final p = OpenCodeZenProvider(apiKey: 'k');
    expect(p.id, 'opencode_zen');
    expect(p.displayName, 'OpenCode Zen');
    expect(p.baseUrl, 'https://opencode.ai/zen/v1');
  });

  test('listModels returns only chat-compatible models', () async {
    final p = OpenCodeZenProvider(apiKey: 'k');
    final models = await p.listModels();
    expect(models, contains('qwen3.6-plus'));
    expect(models, contains('kimi-k2.6'));
    // Should NOT include Claude models (those are /v1/messages)
    expect(models, isNot(contains('claude-sonnet-4-5')));
  });
}
