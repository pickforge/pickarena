class Item {
  Item({required this.id, required this.category});
  final String id;
  final String category;
}

abstract class Filter {
  bool matches(Item item);
}
