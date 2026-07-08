import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:action_bar_overflow/responsive_action_bar.dart';

Widget _host({
  required double width,
  required List<ResponsiveActionBarAction> actions,
  required VoidCallback onPrimaryPressed,
  String primaryLabel = 'Apply',
  TextScaler? textScaler,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    builder: (context, child) {
      if (textScaler == null) return child!;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      );
    },
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

ResponsiveActionBarAction _action(
  String id,
  String label,
  IconData icon,
  Map<String, int> calls, {
  required int priority,
}) {
  return ResponsiveActionBarAction(
    id: id,
    label: label,
    icon: icon,
    priority: priority,
    onPressed: () => calls[id] = (calls[id] ?? 0) + 1,
  );
}

Future<void> _openOverflow(WidgetTester tester) async {
  await tester.tap(find.byKey(ResponsiveActionBar.overflowButtonKey));
  await tester.pumpAndSettle();
}

Future<void> _tapOverflowItem(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ResponsiveActionBar.overflowItemKey(id)));
  await tester.pumpAndSettle();
}

void _expectNoFlutterException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

/// Ids of the actions currently rendered inline (as direct action buttons).
List<String> _inlineActionIds(
  WidgetTester tester,
  List<ResponsiveActionBarAction> actions,
) {
  return <String>[
    for (final action in actions)
      if (find
          .byKey(ResponsiveActionBar.actionButtonKey(action.id))
          .evaluate()
          .isNotEmpty)
        action.id,
  ];
}

/// Actions ranked by the contract: lower priority first, ties by input order.
List<String> _priorityRankedIds(List<ResponsiveActionBarAction> actions) {
  final ranked = actions.indexed.toList()
    ..sort((left, right) {
      final byPriority = left.$2.priority.compareTo(right.$2.priority);
      return byPriority != 0 ? byPriority : left.$1.compareTo(right.$1);
    });
  return ranked.map((entry) => entry.$2.id).toList();
}

/// The inline set must be a priority prefix of the ranked order: no
/// lower-priority action may be overflowed while a higher-number priority
/// action is inline, and equal priorities preserve original input order.
void _expectPriorityPrefix(
  List<ResponsiveActionBarAction> actions,
  List<String> inlineIds,
) {
  final ranked = _priorityRankedIds(actions);
  final expectedPrefix = ranked.take(inlineIds.length).toSet();
  expect(
    inlineIds.toSet(),
    expectedPrefix,
    reason:
        'Inline actions $inlineIds must be a priority prefix of $ranked '
        '(lower priority first, ties by input order).',
  );
}

/// Overflow must contain exactly the complement of the inline set, and no
/// action may appear both inline and in overflow.
Future<void> _expectOverflowIsComplement(
  WidgetTester tester,
  List<ResponsiveActionBarAction> actions,
  List<String> inlineIds,
) async {
  final overflowIds = <String>[
    for (final action in actions)
      if (!inlineIds.contains(action.id)) action.id,
  ];
  if (overflowIds.isEmpty) {
    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsNothing);
    return;
  }
  await _openOverflow(tester);
  for (final id in overflowIds) {
    expect(
      find.byKey(ResponsiveActionBar.overflowItemKey(id)),
      findsOneWidget,
      reason: 'Overflow must contain complement action $id.',
    );
  }
  for (final id in inlineIds) {
    expect(
      find.byKey(ResponsiveActionBar.overflowItemKey(id)),
      findsNothing,
      reason: 'Inline action $id must not also appear in overflow.',
    );
  }
  // Close the overflow menu so callers can tap from a clean state.
  await _openOverflow(tester);
}

/// Taps every action exactly once from wherever it actually rendered:
/// inline actions directly, overflow actions via the overflow menu.
Future<void> _tapEachFromActualLocation(
  WidgetTester tester,
  List<ResponsiveActionBarAction> actions,
  List<String> inlineIds,
) async {
  for (final action in actions) {
    if (inlineIds.contains(action.id)) {
      await tester.tap(
        find.byKey(ResponsiveActionBar.actionButtonKey(action.id)),
      );
      await tester.pump();
    } else {
      await _openOverflow(tester);
      await _tapOverflowItem(tester, action.id);
    }
  }
}

void main() {
  testWidgets(
    'very compact layout keeps primary direct and reaches every secondary from overflow',
    (tester) async {
      final calls = <String, int>{};
      final actions = <ResponsiveActionBarAction>[
        _action('archive', 'Archive', Icons.archive, calls, priority: 0),
        _action(
          'export_csv',
          'Export CSV',
          Icons.file_download,
          calls,
          priority: 10,
        ),
        _action('flag_item', 'Flag item', Icons.flag, calls, priority: 20),
      ];

      await tester.pumpWidget(
        _host(
          width: 256,
          primaryLabel: 'Run',
          actions: actions,
          onPrimaryPressed: () =>
              calls['primary'] = (calls['primary'] ?? 0) + 1,
        ),
      );

      expect(find.byKey(ResponsiveActionBar.primaryButtonKey), findsOneWidget);
      expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsOneWidget);
      for (final action in actions) {
        expect(
          find.byKey(ResponsiveActionBar.actionButtonKey(action.id)),
          findsNothing,
        );
      }

      await tester.tap(find.byKey(ResponsiveActionBar.primaryButtonKey));
      await tester.pump();
      expect(calls['primary'], 1);

      for (final action in actions) {
        await _openOverflow(tester);
        expect(
          find.byKey(ResponsiveActionBar.overflowItemKey(action.id)),
          findsOneWidget,
        );
        await _tapOverflowItem(tester, action.id);
        expect(calls[action.id], 1);
      }
      _expectNoFlutterException(tester);
    },
  );

  testWidgets(
    'medium layout chooses inline action by priority rather than input order',
    (tester) async {
      final calls = <String, int>{};
      final actions = <ResponsiveActionBarAction>[
        _action('broadcast', 'Broadcast', Icons.campaign, calls, priority: 30),
        _action('pin', 'Pin', Icons.push_pin, calls, priority: 0),
        _action('audit', 'Audit', Icons.fact_check, calls, priority: 10),
      ];

      await tester.pumpWidget(
        _host(width: 440, actions: actions, onPrimaryPressed: () {}),
      );

      // No exact inline count is required at this width; the rendered inline
      // set must simply be a priority prefix and overflow its complement.
      final inlineIds = _inlineActionIds(tester, actions);
      _expectPriorityPrefix(actions, inlineIds);
      await _expectOverflowIsComplement(tester, actions, inlineIds);

      await _tapEachFromActualLocation(tester, actions, inlineIds);

      expect(calls, <String, int>{'broadcast': 1, 'pin': 1, 'audit': 1});
      _expectNoFlutterException(tester);
    },
  );

  testWidgets('equal priorities keep earlier input action visible first', (
    tester,
  ) async {
    final calls = <String, int>{};
    final actions = <ResponsiveActionBarAction>[
      _action('first_tie', 'First tied', Icons.looks_one, calls, priority: 5),
      _action('second_tie', 'Second tied', Icons.looks_two, calls, priority: 5),
      _action('later', 'Later action', Icons.more_time, calls, priority: 9),
    ];

    await tester.pumpWidget(
      _host(width: 440, actions: actions, onPrimaryPressed: () {}),
    );

    // No exact inline count is required at this width. The priority-prefix
    // helper catches `second_tie` rendering inline while `first_tie`
    // (equal priority, earlier input order) is overflowed.
    final inlineIds = _inlineActionIds(tester, actions);
    _expectPriorityPrefix(actions, inlineIds);
    await _expectOverflowIsComplement(tester, actions, inlineIds);
    _expectNoFlutterException(tester);
  });

  testWidgets('wide layout preserves inline behavior', (tester) async {
    final calls = <String, int>{};
    final actions = <ResponsiveActionBarAction>[
      _action('receipt', 'Receipt', Icons.receipt_long, calls, priority: 20),
      _action(
        'message_host',
        'Message host',
        Icons.message,
        calls,
        priority: 10,
      ),
      _action(
        'duplicate_trip',
        'Duplicate trip',
        Icons.copy,
        calls,
        priority: 30,
      ),
    ];

    await tester.pumpWidget(
      _host(
        width: 760,
        actions: actions,
        onPrimaryPressed: () => calls['primary'] = (calls['primary'] ?? 0) + 1,
      ),
    );

    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsNothing);
    for (final action in actions) {
      expect(
        find.byKey(ResponsiveActionBar.actionButtonKey(action.id)),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ResponsiveActionBar.actionButtonKey(action.id)),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(ResponsiveActionBar.primaryButtonKey));
    await tester.pump();

    expect(calls, <String, int>{
      'receipt': 1,
      'message_host': 1,
      'duplicate_trip': 1,
      'primary': 1,
    });
    _expectNoFlutterException(tester);
  });

  testWidgets('resize and rebuild do not duplicate or lose actions', (
    tester,
  ) async {
    final calls = <String, int>{};
    final actions = <ResponsiveActionBarAction>[
      _action('print', 'Print', Icons.print, calls, priority: 0),
      _action('refund', 'Refund', Icons.undo, calls, priority: 10),
    ];

    await tester.pumpWidget(
      _host(width: 760, actions: actions, onPrimaryPressed: () {}),
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('print')),
      findsOneWidget,
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('refund')),
      findsOneWidget,
    );
    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsNothing);

    await tester.pumpWidget(
      _host(width: 256, actions: actions, onPrimaryPressed: () {}),
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('print')),
      findsNothing,
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('refund')),
      findsNothing,
    );
    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsOneWidget);

    await _openOverflow(tester);
    expect(
      find.byKey(ResponsiveActionBar.overflowItemKey('print')),
      findsOneWidget,
    );
    expect(
      find.byKey(ResponsiveActionBar.overflowItemKey('refund')),
      findsOneWidget,
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('print')),
      findsNothing,
    );
    await _tapOverflowItem(tester, 'refund');

    await tester.pumpWidget(
      _host(width: 760, actions: actions, onPrimaryPressed: () {}),
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('print')),
      findsOneWidget,
    );
    expect(
      find.byKey(ResponsiveActionBar.actionButtonKey('refund')),
      findsOneWidget,
    );
    expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsNothing);
    await tester.tap(find.byKey(ResponsiveActionBar.actionButtonKey('print')));
    await tester.pump();

    expect(calls, <String, int>{'refund': 1, 'print': 1});
    _expectNoFlutterException(tester);
  });

  testWidgets('semantics remain usable', (tester) async {
    final handle = tester.ensureSemantics();
    final calls = <String, int>{};
    final actions = <ResponsiveActionBarAction>[
      _action(
        'review_order',
        'Review order',
        Icons.rate_review,
        calls,
        priority: 0,
      ),
      _action('send_copy', 'Send copy', Icons.send, calls, priority: 10),
    ];

    await tester.pumpWidget(
      _host(width: 760, actions: actions, onPrimaryPressed: () {}),
    );
    expect(
      tester.getSemantics(
        find.byKey(ResponsiveActionBar.actionButtonKey('review_order')),
      ),
      containsSemantics(
        label: 'Review order',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.pumpWidget(
      _host(width: 256, actions: actions, onPrimaryPressed: () {}),
    );
    expect(
      tester.getSemantics(find.byKey(ResponsiveActionBar.overflowButtonKey)),
      containsSemantics(
        label: 'More actions',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await _openOverflow(tester);
    expect(
      tester.getSemantics(
        find.byKey(ResponsiveActionBar.overflowItemKey('review_order')),
      ),
      containsSemantics(label: 'Review order', hasTapAction: true),
    );
    await _tapOverflowItem(tester, 'review_order');
    expect(calls['review_order'], 1);
    handle.dispose();
    _expectNoFlutterException(tester);
  });

  testWidgets(
    'large text scaling keeps actions reachable and honors ambient scaling',
    (tester) async {
      final calls = <String, int>{};
      final actions = <ResponsiveActionBarAction>[
        _action(
          'quarterly_summary',
          'Quarterly summary export',
          Icons.summarize,
          calls,
          priority: 0,
        ),
        _action(
          'notify_supervisors',
          'Notify all supervisors',
          Icons.notifications_active,
          calls,
          priority: 10,
        ),
      ];

      await tester.pumpWidget(
        _host(
          width: 288,
          primaryLabel: 'Launch',
          actions: actions,
          onPrimaryPressed: () {},
          textScaler: TextScaler.linear(2.0),
        ),
      );

      expect(find.byKey(ResponsiveActionBar.primaryButtonKey), findsOneWidget);
      expect(find.byKey(ResponsiveActionBar.overflowButtonKey), findsOneWidget);
      for (final action in actions) {
        expect(
          find.byKey(ResponsiveActionBar.actionButtonKey(action.id)),
          findsNothing,
        );
      }

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Launch'),
          matching: find.byType(RichText),
        ),
      );
      expect(paragraph.textScaler.scale(10), greaterThan(15));

      await _openOverflow(tester);
      await _tapOverflowItem(tester, 'quarterly_summary');
      expect(calls['quarterly_summary'], 1);
      _expectNoFlutterException(tester);
    },
  );
}
