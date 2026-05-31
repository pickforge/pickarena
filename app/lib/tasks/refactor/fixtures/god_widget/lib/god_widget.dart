import 'package:flutter/material.dart';

class TodoEntry {
  TodoEntry({required this.title, this.done = false});
  String title;
  bool done;
}

List<TodoEntry> _applyFilterAndSort(
  List<TodoEntry> items,
  String filter,
  String sort,
) {
  final filtered = items.where((e) {
    if (filter == 'open') return !e.done;
    if (filter == 'done') return e.done;
    return true;
  }).toList();
  if (sort == 'title') {
    filtered.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  }
  return filtered;
}

String _formatStatus(List<TodoEntry> items) {
  final total = items.length;
  final done = items.where((e) => e.done).length;
  return '$done of $total done';
}

class GodWidget extends StatefulWidget {
  const GodWidget({super.key});
  @override
  State<GodWidget> createState() => _GodWidgetState();
}

class _GodWidgetState extends State<GodWidget> {
  final List<TodoEntry> _items = [];
  final TextEditingController _controller = TextEditingController();
  String _filter = 'all';
  String _sort = 'created';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addFromController() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _items.add(TodoEntry(title: t));
      _controller.clear();
    });
  }

  void _setFilter(String value) => setState(() => _filter = value);

  void _setSort(String value) => setState(() => _sort = value);

  void _toggleEntry(TodoEntry entry, bool value) =>
      setState(() => entry.done = value);

  void _removeEntry(TodoEntry entry) => setState(() => _items.remove(entry));

  @override
  Widget build(BuildContext context) {
    final visible = _applyFilterAndSort(_items, _filter, _sort);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AddTodoBar(controller: _controller, onAdd: _addFromController),
        _FilterSortBar(
          filter: _filter,
          sort: _sort,
          onFilterChanged: _setFilter,
          onSortChanged: _setSort,
        ),
        const Divider(),
        Expanded(
          child: _TodoList(
            entries: visible,
            onToggle: _toggleEntry,
            onDelete: _removeEntry,
          ),
        ),
        _StatusBar(text: _formatStatus(_items)),
      ],
    );
  }
}

class _AddTodoBar extends StatelessWidget {
  const _AddTodoBar({required this.controller, required this.onAdd});

  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'New todo',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: onAdd, child: const Text('Add')),
        ],
      ),
    );
  }
}

class _FilterSortBar extends StatelessWidget {
  const _FilterSortBar({
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final String filter;
  final String sort;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Text('Filter:'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: filter,
            onChanged: (v) => onFilterChanged(v ?? 'all'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'done', child: Text('Done')),
            ],
          ),
          const SizedBox(width: 16),
          const Text('Sort:'),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: sort,
            onChanged: (v) => onSortChanged(v ?? 'created'),
            items: const [
              DropdownMenuItem(value: 'created', child: Text('Created')),
              DropdownMenuItem(value: 'title', child: Text('Title')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodoList extends StatelessWidget {
  const _TodoList({
    required this.entries,
    required this.onToggle,
    required this.onDelete,
  });

  final List<TodoEntry> entries;
  final void Function(TodoEntry entry, bool value) onToggle;
  final void Function(TodoEntry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _TodoTile(
          entry: entry,
          onToggle: (v) => onToggle(entry, v),
          onDelete: () => onDelete(entry),
        );
      },
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.entry,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoEntry entry;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: entry.done,
      onChanged: (v) => onToggle(v ?? false),
      title: Text(
        entry.title,
        style: TextStyle(
          decoration: entry.done ? TextDecoration.lineThrough : null,
        ),
      ),
      secondary: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: onDelete,
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, key: const Key('status'), textAlign: TextAlign.center),
    );
  }
}
