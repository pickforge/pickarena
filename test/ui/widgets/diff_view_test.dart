import 'package:dart_arena/core/unified_diff.dart';
import 'package:dart_arena/ui/widgets/diff_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders one row per DiffLine with kind-based prefix',
      (tester) async {
    await tester.pumpWidget(_wrap(const DiffView(
      lines: [
        DiffLine(DiffLineKind.context, ' foo\n'),
        DiffLine(DiffLineKind.removed, 'bar\n'),
        DiffLine(DiffLineKind.added, 'BAR\n'),
      ],
    )));
    expect(find.textContaining('foo'), findsOneWidget);
    expect(find.textContaining('-'), findsWidgets);
    expect(find.textContaining('+'), findsWidgets);
    expect(find.textContaining('BAR'), findsOneWidget);
  });

  testWidgets('renders empty state for empty input', (tester) async {
    await tester.pumpWidget(_wrap(const DiffView(lines: [])));
    expect(find.text('No diff to show.'), findsOneWidget);
  });
}
