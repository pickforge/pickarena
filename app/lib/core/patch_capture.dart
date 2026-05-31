import 'dart:io';

class PatchCaptureResult {
  const PatchCaptureResult({required this.patch, required this.status});

  final String patch;
  final String status;

  bool get hasMeaningfulDiff => patch.trim().isNotEmpty;
}

class PatchCapture {
  const PatchCapture();

  Future<PatchCaptureResult> capture(Directory workspace) async {
    final intentToAdd = await Process.run('git', [
      'add',
      '-N',
      '.',
    ], workingDirectory: workspace.path);
    if (intentToAdd.exitCode != 0) {
      throw ProcessException(
        'git',
        const ['add', '-N', '.'],
        intentToAdd.stderr.toString(),
        intentToAdd.exitCode,
      );
    }
    final status = await Process.run('git', [
      'status',
      '--porcelain',
    ], workingDirectory: workspace.path);
    final diff = await Process.run('git', [
      'diff',
      '--binary',
    ], workingDirectory: workspace.path);
    if (status.exitCode != 0) {
      throw ProcessException(
        'git',
        const ['status', '--porcelain'],
        status.stderr.toString(),
        status.exitCode,
      );
    }
    if (diff.exitCode != 0) {
      throw ProcessException(
        'git',
        const ['diff', '--binary'],
        diff.stderr.toString(),
        diff.exitCode,
      );
    }
    return PatchCaptureResult(
      patch: diff.stdout.toString(),
      status: status.stdout.toString(),
    );
  }
}
