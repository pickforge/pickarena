import 'package:dart_arena/core/model_response.dart';
import 'package:test/test.dart';

void main() {
  group('ModelResponse', () {
    test('values with same fields are equal', () {
      const a = ModelResponse(
        rawText: 'hi',
        extractedCode: null,
        promptTokens: 1,
        completionTokens: 2,
        latency: Duration(milliseconds: 10),
      );
      const b = ModelResponse(
        rawText: 'hi',
        extractedCode: null,
        promptTokens: 1,
        completionTokens: 2,
        latency: Duration(milliseconds: 10),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
