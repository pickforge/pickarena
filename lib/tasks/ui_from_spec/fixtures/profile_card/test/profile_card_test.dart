import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_card_fixture/profile_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders name and handle', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada Lovelace',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('@ada'), findsOneWidget);
  });

  testWidgets('shows CircleAvatar leading', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      avatarUrl: 'https://example.com/a.png',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('omits bio when null', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    expect(texts, containsAll(<String>['Ada', '@ada']));
    expect(texts.where((t) => t != null && t!.contains('bio')), isEmpty);
  });

  testWidgets('shows bio when provided', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      bio: 'Mathematician.',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.text('Mathematician.'), findsOneWidget);
  });

  testWidgets('follow button shows Follow when not following', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('follow button shows Following when following', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: true,
    )));
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('tapping follow button fires callback', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () => pressed++,
      isFollowing: false,
    )));
    await tester.tap(find.text('Follow'));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('exposes Semantics label for the card', (tester) async {
    await tester.pumpWidget(_wrap(ProfileCard(
      name: 'Ada',
      handle: '@ada',
      onFollowPressed: () {},
      isFollowing: false,
    )));
    expect(
      find.bySemanticsLabel(RegExp(r'Ada.*@ada')),
      findsWidgets,
    );
  });
}
