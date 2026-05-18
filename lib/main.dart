import 'dart:async';
import 'dart:io';

import 'package:dart_arena/app.dart';
import 'package:dart_arena/runner/tmpdir_bootstrap.dart';
import 'package:dart_arena/runner/tmpdir_manager.dart';
import 'package:dart_arena/runner/workdir_manager.dart';
import 'package:dart_arena/storage/database.dart';
import 'package:dart_arena/storage/settings.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  final supportDir = await getApplicationSupportDirectory();

  final tmpRoot = Directory(p.join(supportDir.path, 'tmp'))
    ..createSync(recursive: true);
  bootstrapTmpDir(tmpRoot.path);
  final tmpDirManager = TmpDirManager(root: tmpRoot);
  unawaited(tmpDirManager.sweep());

  final workdirRoot = Directory(p.join(supportDir.path, 'workdirs'))
    ..createSync(recursive: true);
  final workdir = WorkdirManager(root: workdirRoot);
  final settings = SettingsRepository();

  runApp(
    App(
      database: database,
      workdir: workdir,
      settings: settings,
      tmpDirManager: tmpDirManager,
    ),
  );
}
