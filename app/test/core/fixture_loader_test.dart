import 'package:dart_arena/core/fixture_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'FixtureLoader loads listed asset files keyed by relative path',
    () async {
      const root = 'lib/tasks/bug_fix/fixtures/off_by_one_pagination';
      final loader = FixtureLoader(
        assetRoot: root,
        files: const [
          'pubspec.yaml',
          'lib/pagination.dart',
          'test/pagination_test.dart',
        ],
      );

      final map = await loader.load();

      expect(map.keys, {
        'pubspec.yaml',
        'lib/pagination.dart',
        'test/pagination_test.dart',
      });
      expect(map['pubspec.yaml'], isNotEmpty);
      expect(map['pubspec.yaml'], contains('off_by_one_pagination'));
    },
  );

  test('FixtureLoader throws when an asset is missing', () async {
    final loader = FixtureLoader(
      assetRoot: 'no/such/root',
      files: const ['pubspec.yaml'],
    );
    expect(() => loader.load(), throwsA(isA<FlutterError>()));
  });
}
