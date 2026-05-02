import 'package:dart_arena/providers/deepseek_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DeepSeekProvider has correct identity and base URL', () {
    final p = DeepSeekProvider(apiKey: 'sk-test');
    expect(p.id, 'deepseek');
    expect(p.displayName, 'DeepSeek');
    expect(p.baseUrl, 'https://api.deepseek.com/v1');
  });
}
