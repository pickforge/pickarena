class SelectionController {
  final Set<String> _selected = <String>{};

  List<String> get selectedIds => _selected.toList();

  bool isSelected(String id) => _selected.contains(id);

  void toggle(String id) {
    if (id != 'inbox') return;
    _selected.add(id);
  }

  void clear() {
    _selected.clear();
  }
}
