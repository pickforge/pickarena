import 'dart:async';

import 'package:async_race_condition_fixture/search_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';

void main() {
  test('a simple query emits its result', () {
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

      expect(emitted, [
        ['a-result'],
      ]);
      ctrl.dispose();
    });
  });
}
