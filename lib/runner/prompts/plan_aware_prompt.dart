String buildPromptWithPlan({
  required String taskPrompt,
  required String? planMarkdown,
  String? targetContext,
}) {
  final buffer = StringBuffer(taskPrompt);

  final trimmedTargetContext = targetContext?.trim();
  if (trimmedTargetContext != null && trimmedTargetContext.isNotEmpty) {
    buffer.write('''

CURRENT TARGET FILE API/SKELETON:
$trimmedTargetContext''');
  }

  if (planMarkdown != null) {
    buffer.write('''

REFERENCE PLAN:
The following plan was authored by a human and describes the intended implementation approach. You should follow it; deviations are penalized.

```plan
$planMarkdown
```''');
  }

  return buffer.toString();
}

String? buildPromptSafeTargetContext({
  required String targetPath,
  required Map<String, String> fixtures,
  int maxChars = 12000,
}) {
  final source = fixtures[targetPath];
  if (source == null || source.trim().isEmpty) return null;

  final skeleton = _collapseBlankLines(
    _DartSkeletonScanner(source).scan().trimRight(),
  );
  final bounded = _bounded(skeleton, maxChars);
  return '''
File: $targetPath

```dart
$bounded
```''';
}

String? buildPublicTestFixtureContext({
  required Map<String, String> fixtures,
  int maxFiles = 3,
  int maxCharsPerFile = 4000,
  int maxTotalChars = 9000,
}) {
  final entries = fixtures.entries
      .where((entry) => _isPublicTestFixturePath(entry.key))
      .take(maxFiles)
      .toList(growable: false);
  if (entries.isEmpty) return null;

  final buffer = StringBuffer();
  for (final entry in entries) {
    if (buffer.isNotEmpty) buffer.writeln('\n---');
    buffer
      ..writeln('File: ${entry.key}')
      ..writeln()
      ..writeln('```dart')
      ..writeln(_bounded(entry.value.trimRight(), maxCharsPerFile))
      ..writeln('```');
    if (buffer.length >= maxTotalChars) break;
  }

  return _bounded(buffer.toString().trimRight(), maxTotalChars);
}

bool _isPublicTestFixturePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  if (!normalized.startsWith('test/') || !normalized.endsWith('.dart')) {
    return false;
  }
  final segments = normalized.split('/');
  return !segments.any(
    (segment) =>
        segment == '_hidden' ||
        segment == 'hidden' ||
        segment == '_reference' ||
        segment == 'reference',
  );
}

String _bounded(String value, int maxChars) {
  if (value.length <= maxChars) return value;
  return '${value.substring(0, maxChars)}'
      '\n\n[truncated at $maxChars characters]';
}

String _collapseBlankLines(String value) {
  return value.replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

class _DartSkeletonScanner {
  _DartSkeletonScanner(this._source);

  final String _source;
  var _index = 0;

  String scan() => _scanUntilClosingBrace();

  String _scanUntilClosingBrace() {
    final output = StringBuffer();
    while (_index < _source.length) {
      if (_source.startsWith('//', _index)) {
        output.write(_readLineComment());
        continue;
      }
      if (_source.startsWith('/*', _index)) {
        output.write(_readBlockComment());
        continue;
      }

      final char = _source[_index];
      if (char == '"' || char == "'") {
        output.write(_readStringLiteral());
        continue;
      }
      if (char == '}') {
        return output.toString();
      }
      if (_source.startsWith('=>', _index)) {
        output.write('=> /* implementation omitted */');
        _index += 2;
        _skipUntilSemicolon();
        if (_index < _source.length && _source[_index] == ';') {
          output.write(';');
          _index++;
        }
        continue;
      }
      if (char == '{') {
        final header = _recentHeader(output.toString());
        if (_isTypeDeclarationHeader(header)) {
          output.write('{');
          _index++;
          output.write(_scanUntilClosingBrace());
          if (_index < _source.length && _source[_index] == '}') {
            output.write('}');
            _index++;
          }
        } else {
          output.write('{ /* implementation omitted */ }');
          _index++;
          _skipBalancedBlock();
        }
        continue;
      }

      output.write(char);
      _index++;
    }
    return output.toString();
  }

  String _recentHeader(String output) {
    final delimiter = output.lastIndexOf(RegExp(r'[{;}]\s*'));
    final start = delimiter == -1 ? 0 : delimiter + 1;
    return output.substring(start);
  }

  bool _isTypeDeclarationHeader(String header) {
    final normalized = header.replaceAll(RegExp(r'\s+'), ' ').trim();
    return RegExp(
          r'(^| )(sealed |abstract |base |interface |final |mixin )*class \w+',
        ).hasMatch(normalized) ||
        RegExp(r'(^| )mixin \w+').hasMatch(normalized) ||
        RegExp(r'(^| )enum \w+').hasMatch(normalized) ||
        RegExp(r'(^| )extension( \w+)?( on |\s*$)').hasMatch(normalized);
  }

  String _readLineComment() {
    final start = _index;
    final end = _source.indexOf('\n', _index);
    if (end == -1) {
      _index = _source.length;
      return _source.substring(start);
    }
    _index = end + 1;
    return _source.substring(start, _index);
  }

  String _readBlockComment() {
    final start = _index;
    final end = _source.indexOf('*/', _index + 2);
    if (end == -1) {
      _index = _source.length;
      return _source.substring(start);
    }
    _index = end + 2;
    return _source.substring(start, _index);
  }

  String _readStringLiteral() {
    final start = _index;
    final quote = _source[_index];
    final tripleQuote = quote + quote + quote;
    final triple = _source.startsWith(tripleQuote, _index);
    if (triple) {
      final end = _source.indexOf(tripleQuote, _index + 3);
      if (end == -1) {
        _index = _source.length;
        return _source.substring(start);
      }
      _index = end + 3;
      return _source.substring(start, _index);
    }

    _index++;
    while (_index < _source.length) {
      final char = _source[_index];
      if (char == '\\') {
        _index += 2;
        continue;
      }
      _index++;
      if (char == quote) break;
    }
    return _source.substring(start, _index);
  }

  void _skipBalancedBlock() {
    var depth = 1;
    while (_index < _source.length && depth > 0) {
      if (_source.startsWith('//', _index)) {
        _readLineComment();
        continue;
      }
      if (_source.startsWith('/*', _index)) {
        _readBlockComment();
        continue;
      }

      final char = _source[_index];
      if (char == '"' || char == "'") {
        _readStringLiteral();
        continue;
      }
      if (char == '{') depth++;
      if (char == '}') depth--;
      _index++;
    }
  }

  void _skipUntilSemicolon() {
    while (_index < _source.length && _source[_index] != ';') {
      if (_source.startsWith('//', _index)) {
        _readLineComment();
        continue;
      }
      if (_source.startsWith('/*', _index)) {
        _readBlockComment();
        continue;
      }

      final char = _source[_index];
      if (char == '"' || char == "'") {
        _readStringLiteral();
        continue;
      }
      _index++;
    }
  }
}
