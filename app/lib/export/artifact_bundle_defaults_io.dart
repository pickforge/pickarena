import 'dart:io';

import 'package:path/path.dart' as p;

Future<List<Directory>> defaultAllowedTrajectoryRoots() async {
  final appRoot = Directory(p.join(Directory.current.path, '.dart_arena'));
  return [
    Directory(p.join(appRoot.path, 'workdirs', 'runs')),
    Directory(p.join(appRoot.path, 'tmp')),
  ];
}
