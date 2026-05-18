import 'package:dart_arena/app.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/ui/widgets/run_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class RunHistoryPage extends StatefulWidget {
  const RunHistoryPage({super.key, this.dao});

  final RunDao? dao;

  @override
  State<RunHistoryPage> createState() => _RunHistoryPageState();
}

class _RunHistoryPageState extends State<RunHistoryPage> with RouteAware {
  late final RunDao _dao;
  String _query = '';
  Future<List<_RunRowData>>? _future;

  @override
  void initState() {
    super.initState();
    _dao = widget.dao ?? context.read<RunDao>();
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<void>);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _refresh();

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<List<_RunRowData>> _load() async {
    final runs = await _dao.recentRuns(labelQuery: _query);
    final out = <_RunRowData>[];
    for (final run in runs) {
      final taskRuns = await _dao.taskRunsForRun(run.id);
      out.add(_RunRowData(run: run, taskRuns: taskRuns));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Runs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Filter by label',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) {
                _query = v;
                _refresh();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_RunRowData>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No runs yet \u2014 start one from the home page.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final run = rows[i].run;
                    return RunRow(
                      run: run,
                      taskRuns: rows[i].taskRuns,
                      onTap: () => context.push('/runs/${run.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (run.completedAt == null)
                            IconButton(
                              tooltip: 'Mark as completed',
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () => _markCompleted(run),
                            ),
                          IconButton(
                            tooltip: 'Delete run ${run.name ?? run.id}',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(run),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Run run) async {
    final label = run.name ?? 'Run ${run.id}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete run?'),
        content: Text(
          'Delete "$label"? This removes its results and evaluations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _dao.deleteRun(run.id);
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted $label')));
  }

  Future<void> _markCompleted(Run run) async {
    await _dao.markRunCompleted(run.id);
    if (!mounted) return;
    _refresh();
    final label = run.name ?? 'Run ${run.id}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Marked $label as completed')));
  }
}

class _RunRowData {
  const _RunRowData({required this.run, required this.taskRuns});
  final Run run;
  final List<TaskRun> taskRuns;
}
