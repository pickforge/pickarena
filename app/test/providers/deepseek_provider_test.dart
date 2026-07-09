import 'package:dart_arena/providers/deepseek_provider.dart';
import 'package:test/test.dart';

void main() {
  test('DeepSeekProvider has correct identity, base URL, and efforts', () {
    final p = DeepSeekProvider(apiKey: 'sk-test');
    expect(p.id, 'deepseek');
    expect(p.displayName, 'DeepSeek');
    expect(p.baseUrl, 'https://api.deepseek.com/v1');
    expect(p.defaultEfforts, ['high', 'max']);
  });
}
