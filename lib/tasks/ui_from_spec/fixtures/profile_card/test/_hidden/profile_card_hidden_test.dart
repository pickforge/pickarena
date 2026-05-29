import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profile_card_fixture/profile_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

ProfileCard _card({
  String name = 'Ada Lovelace',
  String handle = '@ada',
  String? bio,
  String? avatarUrl,
  bool isFollowing = false,
  VoidCallback? onFollowPressed,
}) {
  return ProfileCard(
    name: name,
    handle: handle,
    bio: bio,
    avatarUrl: avatarUrl,
    isFollowing: isFollowing,
    onFollowPressed: onFollowPressed ?? () {},
  );
}

void main() {
  testWidgets('uses Card Row layout with fallback avatar initial', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_card(name: 'Ada')));

    final card = find.byType(Card);
    expect(card, findsOneWidget);
    expect(
        find.descendant(of: card, matching: find.byType(Row)), findsOneWidget);

    final avatar = find.byType(CircleAvatar);
    expect(avatar, findsOneWidget);
    expect(
      find.descendant(of: avatar, matching: find.text('A')),
      findsOneWidget,
    );
  });

  testWidgets('uses NetworkImage when avatarUrl is provided', (tester) async {
    const url = 'https://example.com/avatar.png';
    await tester.pumpWidget(_wrap(_card(avatarUrl: url)));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<NetworkImage>());
    expect((avatar.backgroundImage! as NetworkImage).url, url);
    tester.takeException();
  });

  testWidgets('renders optional bio only when provided', (tester) async {
    await tester.pumpWidget(_wrap(_card(bio: 'Mathematician.')));
    expect(find.text('Mathematician.'), findsOneWidget);

    await tester.pumpWidget(_wrap(_card()));
    expect(find.text('Mathematician.'), findsNothing);
  });

  testWidgets('follow button reflects state and fires callback',
      (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(_card(isFollowing: true, onFollowPressed: () => pressed++)),
    );

    expect(find.text('Following'), findsOneWidget);
    await tester.tap(find.text('Following'));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('exposes combined name and handle semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_card(name: 'Ada', handle: '@ada')));

    expect(find.bySemanticsLabel('Ada @ada'), findsWidgets);
  });
}
