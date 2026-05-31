import 'dart:isolate';

import 'package:dart_arena/headless/headless_cli_runner.dart';

Future<void> main(List<String> args, Object? message) async {
  if (message is SendPort) {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final code = await runHeadlessCli(
      args,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );
    message.send({
      'exitCode': code,
      'stdout': stdoutLines,
      'stderr': stderrLines,
    });
  }
}
