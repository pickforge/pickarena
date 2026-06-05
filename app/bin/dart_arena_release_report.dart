import 'dart:io';

import 'package:dart_arena/export/release_report_cli_runner.dart';

Future<void> main(List<String> args) async {
  final exitCode = await runReleaseReportCli(args);
  exitCode == 0 ? exit(0) : exit(exitCode);
}
