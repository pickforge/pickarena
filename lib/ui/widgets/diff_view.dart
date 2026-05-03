import 'package:dart_arena/core/unified_diff.dart';
import 'package:flutter/material.dart';

class DiffView extends StatelessWidget {
  const DiffView({super.key, required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Center(child: Text('No diff to show.'));
    }
    return ListView.builder(
      itemCount: lines.length,
      itemBuilder: (context, i) => _DiffLineRow(line: lines[i]),
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});
  final DiffLine line;

  Color _bg(BuildContext context) {
    switch (line.kind) {
      case DiffLineKind.added:
        return Colors.green.withValues(alpha: 0.2);
      case DiffLineKind.removed:
        return Colors.red.withValues(alpha: 0.2);
      case DiffLineKind.context:
        return Colors.transparent;
    }
  }

  String _prefix() {
    switch (line.kind) {
      case DiffLineKind.added:
        return '+ ';
      case DiffLineKind.removed:
        return '- ';
      case DiffLineKind.context:
        return '  ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _bg(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: SelectableText(
        '${_prefix()}${line.text.replaceAll('\n', '')}',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
