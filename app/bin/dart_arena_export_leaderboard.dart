import 'dart:io';

import 'package:dart_arena/export/leaderboard_cli_runner.dart';

Future<void> main(List<String> args) async {
  exitCode = await runLeaderboardExportCli(args);
}
