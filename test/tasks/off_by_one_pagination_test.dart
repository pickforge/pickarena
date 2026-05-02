import 'package:dart_arena/core/category.dart';
import 'package:dart_arena/tasks/bug_fix/off_by_one_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OffByOnePaginationTask metadata is correct', () async {
    await OffByOnePaginationTask.loadAssets();
    final task = OffByOnePaginationTask();
    expect(task.id, 'bug.off_by_one_pagination');
    expect(task.category, Category.bugFix);
    expect(task.prompt, contains('Paginator'));
    expect(task.fixtures.keys, contains('lib/pagination.dart'));
    expect(task.fixtures.keys, contains('test/pagination_test.dart'));
    expect(task.fixtures.keys, contains('pubspec.yaml'));
  });
}
