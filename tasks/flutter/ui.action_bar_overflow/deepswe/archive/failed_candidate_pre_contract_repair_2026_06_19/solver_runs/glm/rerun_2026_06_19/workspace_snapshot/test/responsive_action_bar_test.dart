import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:action_bar_overflow/responsive_action_bar.dart';

Widget _host({
  required double width,
  required List<ResponsiveActionBarAction> actions,
  required VoidCallback onPrimaryPressed,
  String primaryLabel = 'Publish',
}) {
  return MaterialApp(
    locale: const Locale('en'),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: ResponsiveActionBar(
            primaryLabel: primaryLabel,
            onPrimaryPressed: onPrimaryPressed,
            actions: actions,
          ),
        ),
      ),
    ),
  );
}

List<ResponsiveActionBarAction> _publicActions(Map<String, int> calls) {
  void record(String id) {
    calls[id] = (calls[id] ?? 0) + 1;
  }

  return <ResponsiveActionBarAction>[
    ResponsiveActionBarAction(
      id: 'save',
      label: 'Save',
      icon: Icons.save,
      priority: 0,
      onPressed: () => record('save'),
    ),
    ResponsiveActionBarAction(
      id: 'share',
      label: 'Share',
      icon: Icons.share,
      priority: 10,
      onPressed: () => record('share'),
    ),
    ResponsiveActionBarAction(
      id: 'compare',
      label: 'Compare',
      icon: Icons.compare_arrows,
      priority: 20,
      onPressed: () => record('compare'),
    ),
  ];
}

void _expectNoFlutterException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('wide bar renders primary and all actions inline', (
    tester,
  ) async {
    final calls = <String, int>{};
    await tester.pumpWidget(
      _host(
        width: 640,
        actions: _publicActions(calls),
        onPrimaryPressed: () => calls['primary'] = (calls['primary'] ?? 0) + 1,
      ),
    );

    expect(find.byKey(ResponsiveActionBar.primaryButtonKey), findsOneWidget);
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('save')),
      findsOneWidget,
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('share')),
      findsOneWidget,
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('compare')),
      findsOneWidget,
    );
    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsNothing);

    await tester.tap(find.byKey(ResponsiveActionBar.primaryButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(ResponsiveActionBar.actionButtonKey('share')));
    await tester.pump();

    expect(calls['primary'], 1);
    expect(calls['share'], 1);
  });

  testWidgets(
    'compact bar keeps primary visible and moves secondary actions to overflow',
    (tester) async {
      final calls = <String, int>{};
      await tester.pumpWidget(
        _host(
          width: 320,
          actions: _publicActions(calls),
          onPrimaryPressed: () =>
              calls['primary'] = (calls['primary'] ?? 0) + 1,
        ),
      );

      expect(find.byKey(ResponsiveActionBar.primaryButtonKey), findsOneWidget);
      expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsOneWidget);
      expect(
        find.byKey(ResponsiveActionBar.actionButtonKey('save')),
        findsNothing,
      );
      expect(
        find.byKey(ResponsiveActionBar.actionButtonKey('share')),
        findsNothing,
      );
      expect(
        find.byKey(ResponsiveActionBar.actionButtonKey('compare')),
        findsNothing,
      );

      await tester.tap(find.byKey(ResponsiveActionBar.primaryButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(ResponsiveActionBar.overflowButtonKey));
      await tester.pumpAndSettle();

      expect(
        find.byKey(ResponsiveActionBar.overflowItemKey('save')),
        findsOneWidget,
      );
      expect(
        find.byKey(ResponsiveActionBar.overflowItemKey('share')),
        findsOneWidget,
      );
      expect(
        find.byKey(ResponsiveActionBar.overflowItemKey('compare')),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Compare'), findsOneWidget);

      await tester.tap(
        find.byKey(ResponsiveActionBar.overflowItemKey('compare')),
      );
      await tester.pumpAndSettle();

      expect(calls['primary'], 1);
      expect(calls['compare'], 1);
      _expectNoFlutterException(tester);
    },
  );

  testWidgets('public API keys are stable across direct and overflow modes', (
    tester,
  ) async {
    final calls = <String, int>{};
    final actions = _publicActions(calls);

    await tester.pumpWidget(
      _host(width: 640, actions: actions, onPrimaryPressed: () {}),
    );

    expect(find.byKey(ResponsiveActionBar.primaryButtonKey), findsOneWidget);
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('save')),
      findsOneWidget,
    );
    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsNothing);

    await tester.pumpWidget(
      _host(width: 320, actions: actions, onPrimaryPressed: () {}),
    );

    expect(find.byKey(ResponsiveActionBar.primaryButtonKey), findsOneWidget);
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('save')),
      findsNothing,
    );
    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsOneWidget);

    await tester.tap(find.byKey(ResponsiveActionBar.overflowButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ResponsiveActionBar.overflowItemKey('save')),
      findsOneWidget,
    );
    expect(
      find.byKey(ResponsiveActionBar.overflowItemKey('share')),
      findsOneWidget,
    );
    _expectNoFlutterException(tester);
  });
}
