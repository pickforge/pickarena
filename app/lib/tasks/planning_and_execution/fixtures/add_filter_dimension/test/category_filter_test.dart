import 'package:test/test.dart';
import '../lib/category_filter.dart';
import '../lib/filter.dart';

void main() {
  test('CategoryFilter implements Filter', () {
    expect(CategoryFilter(category: 'a'), isA<Filter>());
  });

  test(
    'matches returns true when item.category equals the filter category',
    () {
      final f = CategoryFilter(category: 'red');
      expect(f.matches(Item(id: '1', category: 'red')), isTrue);
      expect(f.matches(Item(id: '2', category: 'blue')), isFalse);
    },
  );

  test('empty category filter matches everything', () {
    final f = CategoryFilter(category: '');
    expect(f.matches(Item(id: '1', category: 'red')), isTrue);
    expect(f.matches(Item(id: '2', category: 'blue')), isTrue);
  });
}
