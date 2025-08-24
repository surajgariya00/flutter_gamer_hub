import 'package:flutter/material.dart';

typedef GameBuilder = Widget Function(BuildContext context);

class GameDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final GameBuilder build;

  const GameDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.build,
  });
}
