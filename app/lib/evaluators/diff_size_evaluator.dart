import 'dart:math' as math;

import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/evaluation_context.dart';
import 'package:dart_arena/core/evaluation_result.dart';
import 'package:dart_arena/core/workspace_path.dart';
import 'package:dart_arena/evaluators/evaluator.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

final _patchTruncationMarker = RegExp(
  r'\[patch truncated at \d+ characters\]\s*$',
);

class DiffSizeEvaluator implements Evaluator {
  DiffSizeEvaluator({required this.originalFixturePath, this.k = 20});

  final String originalFixturePath;
  final int k;

  @override
  String get id => 'diff_size';

  @override
  Future<EvaluationResult> evaluate(EvaluationContext ctx) async {
    final measurement = await _measure(ctx);
    if (measurement == null) {
      return EvaluationResult(
        evaluatorId: id,
        passed: true,
        score: 0.0,
        rationale: 'diff source missing',
        details: {
          'fixture_count': ctx.task.fixtures.length,
          'legacy_path': originalFixturePath,
        },
      );
    }

    final score = math.exp(-measurement.changedLines / k);
    final clamped = score.clamp(0.0, 1.0);

    return EvaluationResult(
      evaluatorId: id,
      passed: true,
      score: clamped,
      rationale: 'changed_lines=${measurement.changedLines}',
      details: {
        'changed_lines': measurement.changedLines,
        'changed_file_count': measurement.changedFileCount,
        'compared_file_count': measurement.comparedFileCount,
        'measurement_source': measurement.source,
        if (measurement.originalLines != null)
          'original_lines': measurement.originalLines,
        if (measurement.newLines != null) 'new_lines': measurement.newLines,
        if (measurement.missingFileCount > 0)
          'missing_file_count': measurement.missingFileCount,
        if (measurement.patchTruncated) 'patch_truncated': true,
        'score_k': k,
      },
    );
  }

  Future<_DiffMeasurement?> _measure(EvaluationContext ctx) async {
    final patch = ctx.response.extractedCode;
    if (ctx.task.track == BenchmarkTrack.agentic && patch != null) {
      final patchMeasurement = _measurePatch(patch);
      if (patchMeasurement != null) return patchMeasurement;
    }
    return _measureFixtureFiles(ctx);
  }

  _DiffMeasurement? _measurePatch(String patch) {
    if (!patch.contains('diff --git ')) return null;

    var changedLines = 0;
    var changedFileCount = 0;
    var inHunk = false;
    for (final line in patch.split('\n')) {
      if (line.startsWith('diff --git ')) {
        changedFileCount++;
        inHunk = false;
        continue;
      }
      if (line.startsWith('@@')) {
        inHunk = true;
        continue;
      }
      if (!inHunk) continue;
      if (line.startsWith(r'\ No newline at end of file')) continue;
      if (line.startsWith('+')) {
        changedLines++;
      } else if (line.startsWith('-')) {
        changedLines++;
      }
    }

    if (changedFileCount == 0) return null;

    return _DiffMeasurement(
      changedLines: changedLines,
      changedFileCount: changedFileCount,
      comparedFileCount: changedFileCount,
      source: 'agent_patch',
      patchTruncated: _patchTruncationMarker.hasMatch(patch),
    );
  }

  Future<_DiffMeasurement?> _measureFixtureFiles(EvaluationContext ctx) async {
    if (ctx.task.fixtures.isEmpty) return null;

    var changedLines = 0;
    var changedFileCount = 0;
    var missingFileCount = 0;
    var originalLines = 0;
    var newLines = 0;
    for (final entry in ctx.task.fixtures.entries) {
      final file = resolveWorkspaceFile(ctx.workDir, entry.key);
      final exists = await file.exists();
      final newContents = exists ? await file.readAsString() : '';
      final changed = _changedLines(entry.value, newContents);
      if (changed > 0) changedFileCount++;
      if (!exists) missingFileCount++;
      changedLines += changed;
      originalLines += _lineCount(entry.value);
      newLines += _lineCount(newContents);
    }

    return _DiffMeasurement(
      changedLines: changedLines,
      changedFileCount: changedFileCount,
      comparedFileCount: ctx.task.fixtures.length,
      originalLines: originalLines,
      newLines: newLines,
      missingFileCount: missingFileCount,
      source: 'workspace_fixtures',
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

  int _lineCount(String contents) => '\n'.allMatches(contents).length + 1;

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

class _DiffMeasurement {
  const _DiffMeasurement({
    required this.changedLines,
    required this.changedFileCount,
    required this.comparedFileCount,
    required this.source,
    this.originalLines,
    this.newLines,
    this.missingFileCount = 0,
    this.patchTruncated = false,
  });

  final int changedLines;
  final int changedFileCount;
  final int comparedFileCount;
  final String source;
  final int? originalLines;
  final int? newLines;
  final int missingFileCount;
  final bool patchTruncated;
}
