import 'dart:io';

sealed class PublishResult {
  const PublishResult();
}

class PublishOk extends PublishResult {
  const PublishOk(this.path);
  final String path;
}

class PublishFailed extends PublishResult {
  const PublishFailed(this.reason);
  final String reason;
}

sealed class ReadmePreview {
  const ReadmePreview();
}

class PreviewOk extends ReadmePreview {
  const PreviewOk(this.updatedContent);
  final String updatedContent;
}

class PreviewFailed extends ReadmePreview {
  const PreviewFailed(this.reason);
  final String reason;
}

class ReadmePublisher {
  static const startMarker = '<!-- BENCHMARK_RESULTS:START -->';
  static const endMarker = '<!-- BENCHMARK_RESULTS:END -->';

  Future<PublishResult> publish({
    required String readmePath,
    required String generatedMarkdown,
  }) async {
    final result = await _splice(readmePath, generatedMarkdown);
    if (result is _SpliceOk) {
      await File(readmePath).writeAsString(result.updated);
      return PublishOk(readmePath);
    }
    return PublishFailed((result as _SpliceFailed).reason);
  }

  Future<ReadmePreview> preview({
    required String readmePath,
    required String generatedMarkdown,
  }) async {
    final result = await _splice(readmePath, generatedMarkdown);
    return switch (result) {
      _SpliceOk(:final updated) => PreviewOk(updated),
      _SpliceFailed(:final reason) => PreviewFailed(reason),
    };
  }

  Future<_SpliceResult> _splice(String path, String generatedMarkdown) async {
    final file = File(path);
    if (!await file.exists()) {
      return _SpliceFailed('README not found at $path');
    }
    final original = await file.readAsString();
    final startIdx = original.indexOf(startMarker);
    final endIdx = original.indexOf(endMarker);
    if (startIdx < 0 || endIdx < 0 || endIdx < startIdx) {
      return const _SpliceFailed(
        'Markers not found. Add\n  $startMarker\n  $endMarker\n'
        'to your README where the results should appear.',
      );
    }
    final before = original.substring(0, startIdx + startMarker.length);
    final after = original.substring(endIdx);
    return _SpliceOk('$before\n$generatedMarkdown\n$after');
  }
}

sealed class _SpliceResult {
  const _SpliceResult();
}

class _SpliceOk extends _SpliceResult {
  const _SpliceOk(this.updated);
  final String updated;
}

class _SpliceFailed extends _SpliceResult {
  const _SpliceFailed(this.reason);
  final String reason;
}
