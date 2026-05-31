class Paginator<T> {
  Paginator(this.items, {this.pageSize = 10});

  final List<T> items;
  final int pageSize;

  int get pageCount =>
      items.isEmpty ? 0 : ((items.length + pageSize - 1) ~/ pageSize);

  List<T> page(int index) {
    if (index < 0) return [];
    final start = index * pageSize;
    if (start >= items.length) return [];
    final end = start + pageSize;
    final actualEnd = end > items.length ? items.length : end;
    return items.sublist(start, actualEnd);
  }
}
