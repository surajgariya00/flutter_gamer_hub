import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/game.dart';

class GameCard extends StatelessWidget {
  final GameDefinition game;
  final VoidCallback onPlay;
  const GameCard({super.key, required this.game, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPlay,
        child: Container(
          decoration: GamerTheme.neonPanel(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(game.icon, size: 36, color: GamerTheme.neonGreen),
                  const SizedBox(width: 12),
                  Expanded(child: Text(game.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  game.description,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("Play"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
