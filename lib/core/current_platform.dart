import 'dart:io' show Platform;

import 'package:dart_arena/core/benchmark_task.dart';

TaskPlatform currentTaskPlatform() {
  if (Platform.isLinux) return TaskPlatform.linux;
  if (Platform.isMacOS) return TaskPlatform.macos;
  if (Platform.isWindows) return TaskPlatform.windows;
  if (Platform.isAndroid) return TaskPlatform.android;
  if (Platform.isIOS) return TaskPlatform.ios;
  return TaskPlatform.linux;
}
