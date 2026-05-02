import 'package:dart_arena/app.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OffByOnePaginationTask.loadAssets();
  runApp(const App());
}
