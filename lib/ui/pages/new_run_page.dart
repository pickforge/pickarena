import 'dart:io';

import 'package:dart_arena/providers/ollama_provider.dart';
import 'package:dart_arena/runner/run_bloc.dart';
import 'package:dart_arena/runner/run_event.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/dao/run_dao.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NewRunPage extends StatefulWidget {
  const NewRunPage({super.key});
  @override
  State<NewRunPage> createState() => _NewRunPageState();
}

class _NewRunPageState extends State<NewRunPage> {
  final _modelController = TextEditingController(text: 'qwen2.5-coder:7b');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Run')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provider: Ollama Local'),
            const SizedBox(height: 8),
            const Text('Task: bug.off_by_one_pagination'),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Ollama model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final settings = SettingsRepository();
                final base = await settings.getOllamaBaseUrl();
                final docs = await getApplicationSupportDirectory();
                final root = Directory(p.join(docs.path, 'workdirs'))
                  ..createSync(recursive: true);
                final db = AppDatabase();
                final bloc = RunBloc(
                  workdirManager: WorkdirManager(root: root),
                  runDao: RunDao(db),
                  now: () => DateTime.now(),
                  idGenerator: () =>
                      'run-${DateTime.now().millisecondsSinceEpoch}',
                );
                final provider = OllamaProvider(
                  id: 'ollama_local',
                  displayName: 'Ollama Local',
                  baseUrl: base,
                  apiKey: null,
                );
                bloc.add(StartRun(
                  tasks: [OffByOnePaginationTask()],
                  providers: [provider],
                  modelByProvider: {'ollama_local': _modelController.text},
                ));
                if (context.mounted) {
                  context.push('/run', extra: bloc);
                }
              },
              child: const Text('Run'),
            ),
          ],
        ),
      ),
    );
  }
}
