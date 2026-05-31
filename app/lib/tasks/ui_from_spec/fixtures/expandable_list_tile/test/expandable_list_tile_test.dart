import 'package:expandable_list_tile_fixture/expandable_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('starts collapsed by default', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ExpandableListTile(
          title: Text('Section'),
          details: Text('Details body'),
        ),
      ),
    );
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Details body'), findsNothing);
  });

  testWidgets('starts expanded when initiallyExpanded is true', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ExpandableListTile(
          title: Text('Section'),
          details: Text('Details body'),
          initiallyExpanded: true,
        ),
      ),
    );
    expect(find.text('Details body'), findsOneWidget);
  });

  testWidgets('tapping the title toggles expansion', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ExpandableListTile(
          title: Text('Section'),
          details: Text('Details body'),
        ),
      ),
    );
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Details body'), findsOneWidget);
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Details body'), findsNothing);
  });

  testWidgets('fires onExpansionChanged with new value', (tester) async {
    final emitted = <bool>[];
    await tester.pumpWidget(
      _wrap(
        ExpandableListTile(
          title: const Text('Section'),
          details: const Text('Details body'),
          onExpansionChanged: emitted.add,
        ),
      ),
    );
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(emitted, [true, false]);
  });

  testWidgets('uses RotationTransition for chevron', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ExpandableListTile(
          title: Text('Section'),
          details: Text('Details body'),
        ),
      ),
    );
    expect(find.byType(RotationTransition), findsAtLeastNWidgets(1));
  });
}
