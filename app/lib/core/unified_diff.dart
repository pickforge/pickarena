import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:equatable/equatable.dart';

enum DiffLineKind { context, added, removed }

class DiffLine extends Equatable {
  const DiffLine(this.kind, this.text);

  final DiffLineKind kind;
  final String text;

  @override
  List<Object?> get props => [kind, text];
}

List<DiffLine> computeUnifiedDiff(String original, String generated) {
  final dmp = DiffMatchPatch();
  final lineArray = <String>[''];
  final lineHash = <String, int>{};

  String linesToChars(String text) {
    final chars = StringBuffer();
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final isLast = i == lines.length - 1;
      final line = isLast ? lines[i] : '${lines[i]}\n';
      if (line.isEmpty && isLast) continue;
      final existing = lineHash[line];
      if (existing != null) {
        chars.writeCharCode(existing);
      } else {
        lineArray.add(line);
        lineHash[line] = lineArray.length - 1;
        chars.writeCharCode(lineArray.length - 1);
      }
    }
    return chars.toString();
  }

  final aChars = linesToChars(original);
  final bChars = linesToChars(generated);
  final diffs = dmp.diff(aChars, bChars);
  dmp.diffCleanupSemantic(diffs);

  final out = <DiffLine>[];
  for (final d in diffs) {
    final kind = switch (d.operation) {
      DIFF_EQUAL => DiffLineKind.context,
      DIFF_INSERT => DiffLineKind.added,
      DIFF_DELETE => DiffLineKind.removed,
      _ => DiffLineKind.context,
    };
    for (final unit in d.text.runes) {
      out.add(DiffLine(kind, lineArray[unit]));
    }
  }
  return out;
}
