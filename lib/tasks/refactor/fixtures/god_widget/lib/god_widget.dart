import 'package:flutter/material.dart';

class TodoEntry {
  TodoEntry({required this.title, this.done = false});
  String title;
  bool done;
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

  List<TodoEntry> get _filteredAndSorted {
    final filtered = _items.where((e) {
      if (_filter == 'open') return !e.done;
      if (_filter == 'done') return e.done;
      return true;
    }).toList();
    if (_sort == 'title') {
      filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return filtered;
  }

  String _statusText() {
    final total = _items.length;
    final done = _items.where((e) => e.done).length;
    return '$done of $total done';
  }

  void _addFromController() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _items.add(TodoEntry(title: t));
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'New todo',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addFromController(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addFromController,
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Text('Filter:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v ?? 'all'),
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
                value: _sort,
                onChanged: (v) => setState(() => _sort = v ?? 'created'),
                items: const [
                  DropdownMenuItem(value: 'created', child: Text('Created')),
                  DropdownMenuItem(value: 'title', child: Text('Title')),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredAndSorted.length,
            itemBuilder: (context, index) {
              final entry = _filteredAndSorted[index];
              return CheckboxListTile(
                value: entry.done,
                onChanged: (v) => setState(() => entry.done = v ?? false),
                title: Text(
                  entry.title,
                  style: TextStyle(
                    decoration: entry.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _items.remove(entry)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _statusText(),
            key: const Key('status'),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
