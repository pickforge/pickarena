import 'dart:io';

class TmpDirManager {
  TmpDirManager({
    required this.root,
    this.maxAge = const Duration(days: 7),
    this.maxBytes = 2 * 1024 * 1024 * 1024,
  });

  final Directory root;
  final Duration maxAge;
  final int maxBytes;

  Future<int> currentSize() async {
    if (!await root.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += entity.statSync().size;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> sweep() async {
    if (!await root.exists()) {
      try {
        await root.create(recursive: true);
      } catch (_) {}
      return;
    }

    final startedAt = DateTime.now();
    final ageCutoff = startedAt.subtract(maxAge);

    List<FileSystemEntity> entries;
    try {
      entries = await root.list(followLinks: false).toList();
    } catch (_) {
      return;
    }

    final survivors = <_Entry>[];
    for (final entity in entries) {
      DateTime modified;
      try {
        modified = entity.statSync().modified;
      } catch (_) {
        continue;
      }
      if (modified.isAfter(startedAt)) {
        survivors.add(_Entry(entity, modified));
        continue;
      }
      if (modified.isBefore(ageCutoff)) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {}
        continue;
      }
      survivors.add(_Entry(entity, modified));
    }

    if (await currentSize() <= maxBytes) return;

    survivors.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in survivors) {
      if (entry.modified.isAfter(startedAt)) continue;
      try {
        await entry.entity.delete(recursive: true);
      } catch (_) {}
      if (await currentSize() <= maxBytes) return;
    }
  }

  Future<void> clear() async {
    if (await root.exists()) {
      try {
        await root.delete(recursive: true);
      } catch (_) {}
    }
    try {
      await root.create(recursive: true);
    } catch (_) {}
  }
}

class _Entry {
  _Entry(this.entity, this.modified);
  final FileSystemEntity entity;
  final DateTime modified;
}
