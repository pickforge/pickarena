import 'package:off_by_one_pagination/pagination.dart';
import 'package:test/test.dart';

void main() {
  group('Paginator', () {
    test('25 items / pageSize 10 yields 3 pages with correct boundaries', () {
      final p = Paginator(List<int>.generate(25, (i) => i));
      expect(p.pageCount, 3);
      expect(p.page(0), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(p.page(1), [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);
      expect(p.page(2), [20, 21, 22, 23, 24]);
    });

    test('exact multiple does not produce empty trailing page', () {
      final p = Paginator(List<int>.generate(20, (i) => i));
      expect(p.pageCount, 2);
      expect(p.page(1), [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]);
    });
  });
}
