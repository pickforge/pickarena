import 'package:dart_arena/providers/openrouter_provider.dart';
import 'package:test/test.dart';

void main() {
  test(
    'OpenRouterProvider has correct identity, base URL, X-Title header, and efforts',
    () {
      final p = OpenRouterProvider(apiKey: 'sk-test');
      expect(p.id, 'openrouter');
      expect(p.displayName, 'OpenRouter');
      expect(p.baseUrl, 'https://openrouter.ai/api/v1');
      expect(p.extraHeaders['X-Title'], 'dart_arena');
      expect(p.defaultEfforts, ['low', 'medium', 'high', 'max']);
    },
  );
}
