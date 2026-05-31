import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_card_fixture/profile_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders name and handle', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProfileCard(
          name: 'Ada Lovelace',
          handle: '@ada',
          onFollowPressed: () {},
          isFollowing: false,
        ),
      ),
    );
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
  });

  testWidgets('follow button shows Follow when not following', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ProfileCard(
          name: 'Ada',
          handle: '@ada',
          onFollowPressed: () {},
          isFollowing: false,
        ),
      ),
    );
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
  });
}
