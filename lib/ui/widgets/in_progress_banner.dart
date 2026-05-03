import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';

class InProgressBanner extends StatelessWidget {
  const InProgressBanner({
    super.key,
    required this.inFlight,
    required this.onTap,
  });

  final List<Run> inFlight;
  final void Function(Run) onTap;

  @override
  Widget build(BuildContext context) {
    if (inFlight.isEmpty) return const SizedBox.shrink();
    final latest = inFlight.reduce(
      (a, b) => a.startedAt.isAfter(b.startedAt) ? a : b,
    );
    final extra = inFlight.length > 1 ? ' · ${inFlight.length} runs in flight' : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(latest),
          child: ListTile(
            leading: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text(latest.name ?? 'Run ${latest.id}'),
            subtitle: Text('In progress$extra'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
  }
}
