import 'dart:async';

import 'package:async_race_condition_fixture/search_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

void main() {
  test('slow result cannot overwrite a newer fast query', () {
    fakeAsync((async) {
      final emitted = <List<String>>[];
      final ctrl = SearchController(
        search: (q) async {
          if (q == 'slow') {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return ['slow-result'];
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ['$q-result'];
        },
      );
      ctrl.results.listen(emitted.add);

      ctrl.onQueryChanged('slow');
      async.elapse(const Duration(milliseconds: 5));
      ctrl.onQueryChanged('fast');
      async.elapse(const Duration(milliseconds: 200));

      expect(emitted, [
        ['fast-result'],
      ]);
      ctrl.dispose();
    });
  });

  test('only the last of three rapid queries emits', () {
    fakeAsync((async) {
      final emitted = <List<String>>[];
      final ctrl = SearchController(
        search: (q) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return [q];
        },
      );
      ctrl.results.listen(emitted.add);

      ctrl.onQueryChanged('first');
      async.elapse(const Duration(milliseconds: 5));
      ctrl.onQueryChanged('second');
      async.elapse(const Duration(milliseconds: 5));
      ctrl.onQueryChanged('third');
      async.elapse(const Duration(milliseconds: 200));

      expect(emitted, [
        ['third'],
      ]);
      ctrl.dispose();
    });
  });

  test('non-overlapping queries each emit', () {
    fakeAsync((async) {
      final emitted = <List<String>>[];
      final ctrl = SearchController(
        search: (q) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return ['$q-result'];
        },
      );
      ctrl.results.listen(emitted.add);

      ctrl.onQueryChanged('a');
      async.elapse(const Duration(milliseconds: 50));
      ctrl.onQueryChanged('b');
      async.elapse(const Duration(milliseconds: 50));

      expect(emitted, [
        ['a-result'],
        ['b-result'],
      ]);
      ctrl.dispose();
    });
  });

  test('dispose before an in-flight search completes emits nothing', () {
    fakeAsync((async) {
      final emitted = <List<String>>[];
      final ctrl = SearchController(
        search: (q) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return ['$q-result'];
        },
      );
      ctrl.results.listen(emitted.add);

      ctrl.onQueryChanged('late');
      ctrl.dispose();
      async.elapse(const Duration(milliseconds: 100));

      expect(emitted, isEmpty);
    });
  });
}
