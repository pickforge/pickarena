import 'package:dart_arena/core/code_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractDartCode', () {
    test('returns content of first ```dart fenced block', () {
      const raw = '''
Some preamble.
```dart
void main() {
  print('hi');
}
```
Trailing.
''';
      expect(extractDartCode(raw), 'void main() {\n  print(\'hi\');\n}\n');
    });

    test('falls back to bare ``` block if dart not specified', () {
      const raw = '''
```
class X {}
```
''';
      expect(extractDartCode(raw), 'class X {}\n');
    });

    test('returns null when no fenced block exists', () {
      expect(extractDartCode('just prose, no code'), isNull);
    });
  });
}
