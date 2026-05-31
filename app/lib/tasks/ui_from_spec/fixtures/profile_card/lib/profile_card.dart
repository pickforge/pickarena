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
    return Semantics(
      label: name,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                onBackgroundImageError: avatarUrl != null ? (_, __) {} : null,
                child: avatarUrl == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(handle),
                    if (bio != null) Text(bio!),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onFollowPressed,
                child: Text(isFollowing ? 'Following' : 'Follow'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
