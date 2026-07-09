import 'package:dart_arena/core/benchmark_task.dart';
import 'package:dart_arena/core/reference_solution.dart';

class PromptSafetyLeakScan {
  const PromptSafetyLeakScan({
    required this.hiddenVerifierLeak,
    required this.referenceLeak,
  });

  final bool hiddenVerifierLeak;
  final bool referenceLeak;
}

PromptSafetyLeakScan scanPromptSafetyLeaks({
  required String visiblePromptContext,
  required BenchmarkTask task,
}) {
  return PromptSafetyLeakScan(
    hiddenVerifierLeak: containsHiddenVerifierPromptSafetyLeak(
      visiblePromptContext,
      task,
    ),
    referenceLeak: containsReferencePromptSafetyLeak(
      visiblePromptContext,
      task,
    ),
  );
}

String buildPromptSafetyVisibleContext({
  required BenchmarkTask task,
  String promptSafeContext = '',
}) {
  final values = <String>[];
  void addVisibleText(String? value) {
    if (value == null || value.trim().isEmpty || values.contains(value)) {
      return;
    }
    values.add(value);
  }

  addVisibleText(task.prompt);
  addVisibleText(task.workspace.instruction);
  addVisibleText(task.referencePlan?.markdown);
  addVisibleText(promptSafeContext);
  return values.join('\n');
}

bool containsHiddenVerifierPromptSafetyLeak(
  String haystack,
  BenchmarkTask task,
) {
  final hiddenPaths = _hiddenVerifierPathTokens(task).toSet();
  final publicFileNames = task.fixtures.keys
      .map(_baseName)
      .map(_normalizePathText)
      .toSet();
  final hiddenFileNames = hiddenPaths
      .map(_baseName)
      .where((name) => !publicFileNames.contains(_normalizePathText(name)))
      .toSet();
  final hiddenFileStems = hiddenFileNames.map(_extensionlessStem).toSet();
  final hiddenContents = task.hiddenVerifiers.expand(
    (verifier) => verifier.files.values,
  );
  return _containsDistinctivePrivateContent(
        haystack: haystack,
        privateContents: hiddenContents,
        publicContents: task.fixtures.values,
      ) ||
      _containsRestrictedHiddenMarker(haystack) ||
      _containsAnyPathLikeToken(haystack, hiddenPaths) ||
      _containsAnyFileNameToken(haystack, hiddenFileNames) ||
      _containsAnyFileStemToken(haystack, hiddenFileStems) ||
      _containsAnyIdentifierToken(haystack, [
        for (final verifier in task.hiddenVerifiers) verifier.id,
        for (final verifier in task.hiddenVerifiers)
          if (verifier.authoredId case final authoredId?) authoredId,
      ]) ||
      _containsAnyPathLikeToken(haystack, _negativeCasePathTokens(task));
}

bool containsReferencePromptSafetyLeak(String haystack, BenchmarkTask task) {
  return switch (task.referenceSolution) {
    ReferenceFileSolution(:final files, :final rootPath) =>
      _containsAnyPathLikeToken(
            haystack,
            _referencePathTokens(task, files.keys, rootPath: rootPath),
          ) ||
          _containsRestrictedReferenceMarker(haystack) ||
          _containsDistinctivePrivateContent(
            haystack: haystack,
            privateContents: files.values,
            publicContents: task.fixtures.values,
          ),
    ReferencePatchSolution(:final patch) => _containsDistinctivePrivateContent(
      haystack: haystack,
      privateContents: [patch],
      publicContents: task.fixtures.values,
    ),
    null => false,
  };
}

Iterable<String> _hiddenVerifierPathTokens(BenchmarkTask task) sync* {
  for (final verifier in task.hiddenVerifiers) {
    yield verifier.testPath;
    yield 'hidden_tests/${verifier.testPath}';
    yield* verifier.files.keys;
    for (final path in verifier.files.keys) {
      yield 'hidden_tests/$path';
    }
  }
}

Iterable<String> _negativeCasePathTokens(BenchmarkTask task) sync* {
  for (final negativeCase in task.negativeCases) {
    final roots = {
      if (negativeCase.rootPath case final rootPath?)
        if (rootPath.trim().isNotEmpty) rootPath,
      'negative_cases/${negativeCase.id}',
      'negative_cases/${negativeCase.kind.wireName}',
    };
    yield* roots;
    switch (negativeCase.solution) {
      case ReferenceFileSolution(:final files):
        for (final path in files.keys) {
          for (final root in roots) {
            yield '$root/$path';
          }
        }
      case ReferencePatchSolution():
        break;
    }
  }
}

Iterable<String> _referencePathTokens(
  BenchmarkTask task,
  Iterable<String> paths, {
  String? rootPath,
}) sync* {
  for (final path in paths) {
    if (rootPath != null && rootPath.trim().isNotEmpty) {
      yield '$rootPath/$path';
    }
    yield 'solution/$path';
    yield 'reference/$path';
    yield '_reference/$path';
    if (!task.fixtures.containsKey(path) && path != task.generatedCodePath) {
      yield path;
    }
  }
}

bool _containsRestrictedHiddenMarker(String haystack) {
  final normalized = _normalizePathText(haystack);
  return _containsPathPrefix(normalized, 'test/_hidden/') ||
      _containsPathPrefix(normalized, 'test/hidden/') ||
      _containsPathPrefix(normalized, '_hidden/') ||
      _containsDirectoryToken(normalized, 'hidden_tests') ||
      _containsAnyIdentifierToken(haystack, const ['do_not_leak_hidden']) ||
      normalized.contains('hidden verifier source');
}

bool _containsRestrictedReferenceMarker(String haystack) {
  final normalized = _normalizePathText(haystack);
  return _containsPathPrefix(normalized, 'test/_reference/') ||
      _containsPathPrefix(normalized, 'test/reference/') ||
      _containsPathPrefix(normalized, '_reference/');
}

bool _containsPathPrefix(String normalizedHaystack, String prefix) {
  final normalizedPrefix = _normalizePathText(prefix);
  return RegExp(
    '(^|[^a-z0-9_-])${RegExp.escape(normalizedPrefix)}',
  ).hasMatch(normalizedHaystack);
}

bool _containsDirectoryToken(String normalizedHaystack, String token) {
  final normalizedToken = _normalizePathText(
    token,
  ).replaceAll(RegExp(r'/+$'), '');
  return RegExp(
    '(^|[^a-z0-9_-])'
    '${RegExp.escape(normalizedToken)}'
    '(?=\$|[^a-z0-9_-])',
  ).hasMatch(normalizedHaystack);
}

bool _containsAnyPathLikeToken(String haystack, Iterable<String> needles) {
  final normalizedHaystack = _normalizePathText(haystack);
  for (final needle in needles) {
    final normalizedNeedle = _normalizePathText(needle.trim());
    if (normalizedNeedle.isEmpty) continue;
    final pattern = RegExp(
      '(^|[^a-z0-9_-])'
      '${RegExp.escape(normalizedNeedle)}'
      '/?(?=\$|[^a-z0-9_./-]|\\.(?:\$|[^a-z0-9_/-]))',
    );
    if (pattern.hasMatch(normalizedHaystack)) return true;
  }
  return false;
}

bool _containsAnyFileNameToken(String haystack, Iterable<String> needles) {
  final normalizedHaystack = _normalizePathText(haystack);
  for (final needle in needles) {
    final normalizedNeedle = _normalizePathText(needle.trim());
    if (normalizedNeedle.isEmpty) continue;
    final pattern = RegExp(
      '(^|[^a-z0-9_.-])'
      '${RegExp.escape(normalizedNeedle)}'
      '(?=\$|[^a-z0-9_.-]|\\.(?:\$|[^a-z0-9_-]))',
    );
    if (pattern.hasMatch(normalizedHaystack)) return true;
  }
  return false;
}

bool _containsAnyFileStemToken(String haystack, Iterable<String> needles) {
  final normalizedHaystack = _normalizePathText(haystack);
  for (final needle in needles) {
    final normalizedNeedle = _normalizePathText(needle.trim());
    if (normalizedNeedle.length < 8) continue;
    final pattern = RegExp(
      '(^|[^a-z0-9_-])'
      '${RegExp.escape(normalizedNeedle)}'
      '(?=\$|[^a-z0-9_-])',
    );
    if (pattern.hasMatch(normalizedHaystack)) return true;
  }
  return false;
}

bool _containsAnyIdentifierToken(String haystack, Iterable<String> needles) {
  final normalizedHaystack = haystack.toLowerCase();
  for (final needle in needles) {
    final normalizedNeedle = needle.trim().toLowerCase();
    if (normalizedNeedle.length < 8) continue;
    final pattern = RegExp(
      '(^|[^a-z0-9_])'
      '${RegExp.escape(normalizedNeedle)}'
      '(?=\$|[^a-z0-9_])',
    );
    if (pattern.hasMatch(normalizedHaystack)) return true;
  }
  return false;
}

bool _containsDistinctivePrivateContent({
  required String haystack,
  required Iterable<String> privateContents,
  required Iterable<String> publicContents,
}) {
  final normalizedHaystack = _normalizeDistinctiveContent(haystack);
  final normalizedPublic = _normalizeDistinctiveContent(
    publicContents.join('\n'),
  );
  for (final content in privateContents) {
    for (final window in _distinctivePrivateWindows(content)) {
      final normalizedWindow = _normalizeDistinctiveContent(window);
      if (normalizedPublic.contains(normalizedWindow)) continue;
      if (normalizedHaystack.contains(normalizedWindow)) return true;
    }
    for (final snippet in _distinctivePrivateSnippets(content)) {
      final normalizedSnippet = _normalizeDistinctiveContent(snippet);
      if (normalizedPublic.contains(normalizedSnippet)) continue;
      if (normalizedHaystack.contains(normalizedSnippet)) return true;
    }
  }
  return false;
}

Iterable<String> _distinctivePrivateWindows(String content) sync* {
  const windowSize = 3;
  final lines = [
    for (final line in content.split('\n'))
      if (_isNonTrivialPrivateLine(line)) line.trim(),
  ];
  if (lines.length < windowSize) return;
  for (var i = 0; i <= lines.length - windowSize; i++) {
    yield lines.skip(i).take(windowSize).join('\n');
  }
}

bool _isNonTrivialPrivateLine(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return false;
  final lower = trimmed.toLowerCase();
  return !lower.startsWith('import ') &&
      !lower.startsWith('export ') &&
      !lower.startsWith('part ') &&
      !lower.startsWith('//') &&
      !lower.startsWith('/*') &&
      !lower.startsWith('*');
}

Iterable<String> _distinctivePrivateSnippets(String content) sync* {
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (_isDistinctivePrivateSnippet(trimmed)) yield trimmed;
  }
}

bool _isDistinctivePrivateSnippet(String value) {
  final normalized = _normalizeWhitespace(value);
  if (normalized.length < 18) return false;
  final lower = normalized.toLowerCase();
  if (lower.startsWith('import ') ||
      lower.startsWith('export ') ||
      lower.startsWith('part ') ||
      lower.startsWith('//') ||
      lower.startsWith('/*') ||
      lower.startsWith('*') ||
      lower == '@override') {
    return false;
  }
  if (!RegExp(r'''[(){}\[\].,;:=><+\-*/'"|&]''').hasMatch(normalized)) {
    return false;
  }
  final tokens = RegExp(r'[A-Za-z_][A-Za-z0-9_]*|\d+(?:\.\d+)?')
      .allMatches(normalized)
      .map((match) => match.group(0)!.toLowerCase())
      .toSet();
  return tokens.length >= 3;
}

String _normalizePathText(String value) =>
    value.replaceAll('\\', '/').toLowerCase();

String _normalizeWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalizeDistinctiveContent(String value) {
  final collapsed = _normalizeWhitespace(value).toLowerCase();
  return collapsed.replaceAllMapped(
    RegExp(r'''\s*([(){}\[\].,;:=><+\-*/'"|&])\s*'''),
    (match) => match.group(1)!,
  );
}

String _baseName(String value) {
  final normalized = value.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash == -1) return normalized;
  return normalized.substring(slash + 1);
}

String _extensionlessStem(String value) {
  final dot = value.lastIndexOf('.');
  if (dot <= 0) return value;
  return value.substring(0, dot);
}
