import 'package:dart_arena/core/code_extractor.dart';
import 'package:test/test.dart';

void main() {
  group('extractJsonBlock', () {
    test('returns content of first ```json fenced block', () {
      const raw = '''
Some text.
```json
{"score": 0.9, "rationale": "ok"}
```
trailing.
''';
      expect(extractJsonBlock(raw), '{"score": 0.9, "rationale": "ok"}\n');
    });

    test('falls back to bare ``` block when json not labeled', () {
      const raw = '''
```
{"a": 1}
```
''';
      expect(extractJsonBlock(raw), '{"a": 1}\n');
    });

    test('returns null when no fenced block', () {
      expect(extractJsonBlock('no fences here'), isNull);
    });
  });
}
