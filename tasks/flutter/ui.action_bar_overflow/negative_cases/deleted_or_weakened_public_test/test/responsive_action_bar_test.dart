import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:action_bar_overflow/responsive_action_bar.dart';

void main() {
  testWidgets('action bar can be constructed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveActionBar(
            primaryLabel: 'Publish',
            onPrimaryPressed: () {},
            actions: const <ResponsiveActionBarAction>[],
          ),
        ),
      ),
    );

    expect(find.byType(ResponsiveActionBar), findsOneWidget);
  });
}
