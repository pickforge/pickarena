import 'dart:io';

import 'package:dart_arena/runner/task_qa_cli_runner.dart';

Future<void> main(List<String> args) async {
  exitCode = await runTaskQaCli(args);
}
