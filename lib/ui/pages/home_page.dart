import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('dart_arena'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => context.push('/new-run'),
              child: const Text('New Run'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.push('/runs'),
              child: const Text('View history'),
            ),
          ],
        ),
      ),
    );
  }
}
