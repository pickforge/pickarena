import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<List<Directory>> defaultAllowedTrajectoryRoots() async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    return [
      Directory(p.join(supportDir.path, 'workdirs', 'runs')),
      Directory(p.join(supportDir.path, 'tmp')),
    ];
  } on Object {
    return const [];
  }
}
