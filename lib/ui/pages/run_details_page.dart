import 'dart:io';

import 'package:dart_arena/export/csv_exporter.dart';
import 'package:dart_arena/export/md_exporter.dart';
import 'package:dart_arena/export/readme_publisher.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/run_summary.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/ui/widgets/run_matrix.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RunDetailsPage extends StatefulWidget {
  const RunDetailsPage({
    super.key,
    required this.runId,
    this.dao,
    this.settings,
    this.publisher,
  });

  final String runId;
  final RunDao? dao;
  final SettingsRepository? settings;
  final ReadmePublisher? publisher;

  @override
  State<RunDetailsPage> createState() => _RunDetailsPageState();
}

class _RunDetailsPageState extends State<RunDetailsPage> {
  late final RunDao _dao;
  late final SettingsRepository _settings;
  late final ReadmePublisher _publisher;
  AppDatabase? _ownedDb;
  Future<RunSummary?>? _future;
  String? _readmePath;

  @override
  void initState() {
    super.initState();
    if (widget.dao == null) {
      _ownedDb = AppDatabase();
      _dao = RunDao(_ownedDb!);
    } else {
      _dao = widget.dao!;
    }
    _settings = widget.settings ?? SettingsRepository();
    _publisher = widget.publisher ?? ReadmePublisher();
    _future = _dao.loadSummary(widget.runId);
    _settings.getReadmePath().then((p) {
      if (mounted) setState(() => _readmePath = p);
    });
  }

  @override
  void dispose() {
    _ownedDb?.close();
    super.dispose();
  }

  Future<void> _saveCsv(RunSummary s) async {
    final csv = runSummaryToCsv(s);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save run as CSV',
      fileName: 'run-${s.run.id}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (path == null) return;
    await File(path).writeAsString(csv);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $path')),
    );
  }

  Future<void> _saveMd(RunSummary s) async {
    final md = runSummaryToMarkdown(s);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save run as Markdown',
      fileName: 'run-${s.run.id}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    if (path == null) return;
    await File(path).writeAsString(md);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to $path')),
    );
  }

  Future<void> _publishToReadme(RunSummary s) async {
    if (_readmePath == null) return;
    final md = runSummaryToMarkdown(s);
    final preview = await _publisher.preview(
      readmePath: _readmePath!,
      generatedMarkdown: md,
    );
    if (!mounted) return;

    if (preview is PreviewFailed) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot publish'),
          content: SingleChildScrollView(child: Text(preview.reason)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final updated = (preview as PreviewOk).updatedContent;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Publish to README'),
        content: SizedBox(
          width: 700,
          height: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              updated,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _publisher.publish(
      readmePath: _readmePath!,
      generatedMarkdown: md,
    );
    if (!mounted) return;
    final msg = result is PublishOk
        ? 'Published to ${result.path}'
        : 'Failed: ${(result as PublishFailed).reason}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run details')),
      body: FutureBuilder<RunSummary?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snap.data;
          if (summary == null) {
            return const Center(child: Text('Run not found.'));
          }
          final inProgress = summary.run.completedAt == null;
          final canPublish = _readmePath != null && !inProgress;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.run.name ?? 'Run ${summary.run.id}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Started ${summary.run.startedAt.toIso8601String()} '
                            '\u00b7 ${inProgress ? 'in progress' : 'completed ${summary.run.completedAt!.toIso8601String()}'} '
                            '\u00b7 ${summary.taskRuns.length} task-runs',
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: inProgress ? null : () => _saveCsv(summary),
                          child: const Text('Export CSV'),
                        ),
                        TextButton(
                          onPressed: inProgress ? null : () => _saveMd(summary),
                          child: const Text('Export Markdown'),
                        ),
                        Tooltip(
                          message: _readmePath == null
                              ? 'Set README path in Settings'
                              : '',
                          child: TextButton(
                            onPressed: canPublish
                                ? () => _publishToReadme(summary)
                                : null,
                            child: const Text('Publish to README'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (inProgress)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: Color(0xFF333333),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Run still in progress; results will appear as task-runs complete.',
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: summary.taskRuns.isEmpty
                    ? const Center(
                        child: Text(
                          'Run failed before any task completed.',
                        ),
                      )
                    : RunMatrix(
                        taskRuns: summary.taskRuns,
                        onCellTap: (tr) => context.push(
                          '/runs/${summary.run.id}/task-runs/${tr.id}',
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
