import 'dart:io';
import 'package:flutter/material.dart';

import '../character/profile.dart';

class GameOverPage extends StatelessWidget {
  final Profile player;

  const GameOverPage({super.key, required this.player});

  Future<void> _handleRestart(BuildContext context) async {
    await player.resetStats();

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Game restarted — good luck!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "GAME OVER",
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Avatar
              _buildAvatar(),

              Text(
                "Your journey ends here...",
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              ElevatedButton.icon(
                onPressed: () => _handleRestart(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text("Restart"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (player.avatarPath == null) return const SizedBox.shrink();

    final file = File(player.avatarPath!);
    if (!file.existsSync()) return const SizedBox.shrink();

    return Column(
      children: [
        CircleAvatar(radius: 50, backgroundImage: FileImage(file)),
        const SizedBox(height: 24),
      ],
    );
  }
}
