import 'dart:io';

import 'package:dart_arena/export/readme_publisher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _markers = '''
# My Project

Some prose.

<!-- BENCHMARK_RESULTS:START -->
old content
<!-- BENCHMARK_RESULTS:END -->

More prose.
''';

void main() {
  late Directory tmp;
  late String readmePath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dart_arena_readme_');
    readmePath = p.join(tmp.path, 'README.md');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test('publish replaces content between markers', () async {
    File(readmePath).writeAsStringSync(_markers);

    final pub = ReadmePublisher();
    final result = await pub.publish(
      readmePath: readmePath,
      generatedMarkdown: 'NEW CONTENT',
    );

    expect(result, isA<PublishOk>());
    final updated = File(readmePath).readAsStringSync();
    expect(updated, contains('# My Project'));
    expect(updated, contains('Some prose.'));
    expect(updated, contains('More prose.'));
    expect(updated, contains('NEW CONTENT'));
    expect(updated, isNot(contains('old content')));
  });

  test('publish preserves text before start and after end markers', () async {
    File(readmePath).writeAsStringSync(_markers);

    await ReadmePublisher().publish(
      readmePath: readmePath,
      generatedMarkdown: 'X',
    );

    final updated = File(readmePath).readAsStringSync();
    expect(updated.split('\n').first, '# My Project');
    expect(updated.trim().endsWith('More prose.'), isTrue);
  });

  test('publish fails when README does not exist', () async {
    final result = await ReadmePublisher().publish(
      readmePath: '/no/such/file.md',
      generatedMarkdown: 'X',
    );
    expect(result, isA<PublishFailed>());
    expect((result as PublishFailed).reason, contains('not found'));
  });

  test('publish fails when markers are missing', () async {
    File(readmePath).writeAsStringSync('# Just a README\n\nNo markers here.\n');
    final result = await ReadmePublisher().publish(
      readmePath: readmePath,
      generatedMarkdown: 'X',
    );
    expect(result, isA<PublishFailed>());
    expect((result as PublishFailed).reason, contains('Markers not found'));
  });

  test('publish fails when end marker comes before start marker', () async {
    File(readmePath).writeAsStringSync('''
<!-- BENCHMARK_RESULTS:END -->
backwards
<!-- BENCHMARK_RESULTS:START -->
''');
    final result = await ReadmePublisher().publish(
      readmePath: readmePath,
      generatedMarkdown: 'X',
    );
    expect(result, isA<PublishFailed>());
  });

  test('preview returns updated content without writing the file', () async {
    File(readmePath).writeAsStringSync(_markers);

    final preview = await ReadmePublisher().preview(
      readmePath: readmePath,
      generatedMarkdown: 'PREVIEW',
    );

    expect(preview, isA<PreviewOk>());
    expect((preview as PreviewOk).updatedContent, contains('PREVIEW'));

    // File on disk is untouched.
    final unchanged = File(readmePath).readAsStringSync();
    expect(unchanged, contains('old content'));
    expect(unchanged, isNot(contains('PREVIEW')));
  });

  test('preview surfaces missing file as PreviewFailed', () async {
    final preview = await ReadmePublisher().preview(
      readmePath: '/no/such/file.md',
      generatedMarkdown: 'X',
    );
    expect(preview, isA<PreviewFailed>());
  });
}
