import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    required this.handle,
    this.bio,
    this.avatarUrl,
    required this.onFollowPressed,
    required this.isFollowing,
  });

  final String name;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final VoidCallback onFollowPressed;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) {
    // TODO: build a card matching the spec.
    return const SizedBox.shrink();
  }
}
