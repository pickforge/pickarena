import 'package:dart_arena/providers/openai_provider.dart';
import 'package:test/test.dart';

void main() {
  test('OpenAIProvider has correct identity, base URL, and efforts', () {
    final p = OpenAIProvider(apiKey: 'sk-test');
    expect(p.id, 'openai');
    expect(p.displayName, 'OpenAI');
    expect(p.baseUrl, 'https://api.openai.com/v1');
    expect(p.defaultEfforts, ['low', 'medium', 'high', 'xhigh']);
  });
}
