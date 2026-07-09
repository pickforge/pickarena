import 'package:dart_arena/core/unified_diff.dart';
import 'package:test/test.dart';

void main() {
  group('computeUnifiedDiff', () {
    test('identical inputs produce only context lines', () {
      const a = 'foo\nbar\nbaz\n';
      final result = computeUnifiedDiff(a, a);
      expect(result.every((l) => l.kind == DiffLineKind.context), isTrue);
      expect(result.map((l) => l.text).join(), a);
    });

    test('addition produces an added line', () {
      const a = 'foo\nbar\n';
      const b = 'foo\nbar\nbaz\n';
      final result = computeUnifiedDiff(a, b);
      final added = result.where((l) => l.kind == DiffLineKind.added).toList();
      expect(added, hasLength(1));
      expect(added.first.text, 'baz\n');
    });

    test('removal produces a removed line', () {
      const a = 'foo\nbar\nbaz\n';
      const b = 'foo\nbaz\n';
      final result = computeUnifiedDiff(a, b);
      final removed = result
          .where((l) => l.kind == DiffLineKind.removed)
          .toList();
      expect(removed, hasLength(1));
      expect(removed.first.text, 'bar\n');
    });

    test('replace produces both removed and added', () {
      const a = 'foo\nbar\n';
      const b = 'foo\nBAZ\n';
      final result = computeUnifiedDiff(a, b);
      final removed = result.where((l) => l.kind == DiffLineKind.removed);
      final added = result.where((l) => l.kind == DiffLineKind.added);
      expect(removed.map((l) => l.text), contains('bar\n'));
      expect(added.map((l) => l.text), contains('BAZ\n'));
    });

    test('empty original to non-empty produces all-added', () {
      const a = '';
      const b = 'x\ny\n';
      final result = computeUnifiedDiff(a, b);
      expect(result.every((l) => l.kind == DiffLineKind.added), isTrue);
    });
  });
}
