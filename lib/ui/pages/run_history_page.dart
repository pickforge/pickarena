import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RunHistoryPage extends StatefulWidget {
  const RunHistoryPage({super.key, this.dao});

  final RunDao? dao;

  @override
  State<RunHistoryPage> createState() => _RunHistoryPageState();
}

class _RunHistoryPageState extends State<RunHistoryPage> {
  late final RunDao _dao;
  AppDatabase? _ownedDb;
  String _query = '';
  Future<List<_RunRowData>>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.dao == null) {
      _ownedDb = AppDatabase();
      _dao = RunDao(_ownedDb!);
    } else {
      _dao = widget.dao!;
    }
    _refresh();
  }

  @override
  void dispose() {
    _ownedDb?.close();
    super.dispose();
  }

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
                    child:
                        Text('No runs yet \u2014 start one from the home page.'),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _RunTile(
                    data: rows[i],
                    onTap: () => context.push('/runs/${rows[i].run.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RunRowData {
  const _RunRowData({required this.run, required this.taskRuns});
  final Run run;
  final List<TaskRun> taskRuns;
}

class _RunTile extends StatelessWidget {
  const _RunTile({required this.data, required this.onTap});

  final _RunRowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final run = data.run;
    final title = run.name ?? 'Run ${run.id}';
    final taskCount = data.taskRuns.map((t) => t.taskId).toSet().length;
    final modelCount = data.taskRuns
        .map((t) => '${t.providerId}/${t.modelId}')
        .toSet()
        .length;
    final avg = data.taskRuns.isEmpty
        ? null
        : data.taskRuns
                .map((t) => t.aggregateScore)
                .reduce((a, b) => a + b) /
            data.taskRuns.length;
    final ts = run.startedAt.toIso8601String();
    return ListTile(
      title: Text(title),
      subtitle: Text(
        '$ts \u00b7 $taskCount tasks \u00b7 $modelCount models'
        '${avg == null ? '' : ' \u00b7 avg ${avg.toStringAsFixed(2)}'}',
      ),
      trailing: run.completedAt == null
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
