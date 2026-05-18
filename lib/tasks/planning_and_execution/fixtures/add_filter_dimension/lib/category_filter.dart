import 'filter.dart';

class CategoryFilter implements Filter {
  CategoryFilter({required this.category});

  final String category;

  @override
  bool matches(Item item) {
    if (category.isEmpty) return true;
    return item.category == category;
  }
}
