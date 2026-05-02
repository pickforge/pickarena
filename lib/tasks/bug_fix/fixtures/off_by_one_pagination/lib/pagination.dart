class Paginator<T> {
  Paginator(this.items, {this.pageSize = 10});

  final List<T> items;
  final int pageSize;

  int get pageCount => (items.length / pageSize).floor();

  List<T> page(int index) {
    final start = index * pageSize;
    final end = start + pageSize;
    return items.sublist(start, end > items.length ? items.length - 1 : end);
  }
}
