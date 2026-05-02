import 'dart:io';
import 'dart:math' as math;

import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:path/path.dart' as p;

class DiffSizeEvaluator implements Evaluator {
  DiffSizeEvaluator({required this.originalFixturePath, this.k = 20});

  final String originalFixturePath;
  final int k;

  @override
  String get id => 'diff_size';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final original = ctx.task.fixtures[originalFixturePath];
    final newFile = File(p.join(ctx.workDir.path, originalFixturePath));
    if (original == null || !newFile.existsSync()) {
      return EvaluationResult(
        evaluatorId: id,
        passed: false,
        score: 0.0,
        rationale: 'diff source missing',
        details: {
          'original_present': original != null,
          'new_file_present': newFile.existsSync(),
          'path': originalFixturePath,
        },
      );
    }

    final newContents = await newFile.readAsString();
    final changed = _changedLines(original, newContents);
    final score = math.exp(-changed / k);
    final clamped = score.clamp(0.0, 1.0);

    return EvaluationResult(
      evaluatorId: id,
      passed: clamped >= 0.3,
      score: clamped,
      rationale: 'changed_lines=$changed',
      details: {
        'original_lines': '\n'.allMatches(original).length + 1,
        'new_lines': '\n'.allMatches(newContents).length + 1,
        'changed_lines': changed,
        'score_k': k,
      },
    );
  }

  int _changedLines(String a, String b) {
    final dmp = DiffMatchPatch();
    final map = <String, String>{};
    final aEnc = _encode(a.split('\n'), map);
    final bEnc = _encode(b.split('\n'), map);

    final diffs = dmp.diff(aEnc, bEnc);
    dmp.diffCleanupSemantic(diffs);

    var changed = 0;
    for (final d in diffs) {
      if (d.operation == DIFF_INSERT || d.operation == DIFF_DELETE) {
        changed += d.text.length;
      }
    }
    return changed;
  }

  String _encode(List<String> lines, Map<String, String> map) {
    final buf = StringBuffer();
    for (final line in lines) {
      final existing = map[line];
      if (existing != null) {
        buf.write(existing);
      } else {
        final code = String.fromCharCode(map.length + 1);
        map[line] = code;
        buf.write(code);
      }
    }
    return buf.toString();
  }
}
