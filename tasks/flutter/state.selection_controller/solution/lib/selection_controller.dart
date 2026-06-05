class SelectionController {
  final Set<String> _selected = <String>{};

  List<String> get selectedIds => _selected.toList()..sort();

  bool isSelected(String id) => _selected.contains(id);

  void toggle(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return;
    if (!_selected.add(normalized)) {
      _selected.remove(normalized);
    }
  }

  void clear() {
    _selected.clear();
  }
}
