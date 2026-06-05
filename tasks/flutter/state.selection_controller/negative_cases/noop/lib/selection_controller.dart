class SelectionController {
  final Set<String> _selected = <String>{};

  List<String> get selectedIds => _selected.toList();

  bool isSelected(String id) => _selected.contains(id);

  void toggle(String id) {
    _selected
      ..clear()
      ..add(id);
  }

  void clear() {
    _selected.clear();
  }
}
