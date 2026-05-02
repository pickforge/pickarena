import 'package:dart_arena/providers/openai_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenAIProvider has correct identity and base URL', () {
    final p = OpenAIProvider(apiKey: 'sk-test');
    expect(p.id, 'openai');
    expect(p.displayName, 'OpenAI');
    expect(p.baseUrl, 'https://api.openai.com/v1');
  });
}
