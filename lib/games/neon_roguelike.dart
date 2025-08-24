// lib/games/neon_roguelike.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/progress_service.dart';

class NeonRoguelikeScreen extends StatefulWidget {
  const NeonRoguelikeScreen({super.key});
  @override
  State<NeonRoguelikeScreen> createState() => _NeonRoguelikeScreenState();
}

class _NeonRoguelikeScreenState extends State<NeonRoguelikeScreen> {
  static const int cols = 31;
  static const int rows = 19;
  late List<List<int>> map; // 0 floor, 1 wall, 2 stairs
  Point<int> player = const Point(2, 2);
  List<Point<int>> enemies = [];
  int hp = 5;
  int depth = 1;
  int score = 0;
  int bestDepth = 1;
  int bestScore = 0;
  final rand = Random();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('rogue') as Map?;
    bestDepth = (data?['bestDepth'] as int?) ?? 1;
    bestScore = (data?['bestScore'] as int?) ?? 0;
    _generateFloor();
  }

  void _persistBest() async {
    await ProgressService.write('rogue', {
      'bestDepth': bestDepth,
      'bestScore': bestScore,
    });
  }

  void _generateFloor() {
    // Start with walls
    map = List.generate(rows, (_) => List.filled(cols, 1));
    // carve rooms
    Point<int>? prevCenter;
    for (int i = 0; i < 7; i++) {
      final w = rand.nextInt(6) + 4;
      final h = rand.nextInt(4) + 3;
      final x = rand.nextInt(cols - w - 2) + 1;
      final y = rand.nextInt(rows - h - 2) + 1;
      for (int yy = y; yy < y + h; yy++) {
        for (int xx = x; xx < x + w; xx++) {
          map[yy][xx] = 0;
        }
      }
      final center = Point(x + w ~/ 2, y + h ~/ 2);
      if (prevCenter != null) {
        // corridor
        for (
          int xx = min(center.x, prevCenter.x);
          xx <= max(center.x, prevCenter.x);
          xx++
        ) {
          map[prevCenter.y][xx] = 0;
        }
        for (
          int yy = min(center.y, prevCenter.y);
          yy <= max(center.y, prevCenter.y);
          yy++
        ) {
          map[yy][center.x] = 0;
        }
      }
      prevCenter = center;
    }
    // stairs
    late Point<int> stairs;
    while (true) {
      final s = Point(rand.nextInt(cols - 2) + 1, rand.nextInt(rows - 2) + 1);
      if (map[s.y][s.x] == 0) {
        stairs = s;
        break;
      }
    }
    map[stairs.y][stairs.x] = 2;

    // place player
    while (true) {
      final p = Point(rand.nextInt(cols - 2) + 1, rand.nextInt(rows - 2) + 1);
      if (map[p.y][p.x] == 0 && (p - stairs).magnitude > 6) {
        player = p;
        break;
      }
    }

    // enemies
    enemies = [];
    final n = 4 + depth;
    while (enemies.length < n) {
      final e = Point(rand.nextInt(cols - 2) + 1, rand.nextInt(rows - 2) + 1);
      if (map[e.y][e.x] == 0 && e != player && e != stairs) enemies.add(e);
    }

    hp = min(6, hp + 1); // tiny heal per floor
    setState(() {});
  }

  bool _walkable(Point<int> p) =>
      p.x >= 0 && p.x < cols && p.y >= 0 && p.y < rows && map[p.y][p.x] != 1;

  void _move(Point<int> d) async {
    final np = Point(player.x + d.x, player.y + d.y);
    if (!_walkable(np)) return;
    player = np;
    score += 1;

    // stairs?
    if (map[player.y][player.x] == 2) {
      depth += 1;
      bestDepth = max(bestDepth, depth);
      bestScore = max(bestScore, score);
      _persistBest();
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: GamerTheme.card,
          title: const Text('Descend!', style: TextStyle(color: Colors.white)),
          content: Text(
            'Depth: $depth    Score: $score',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go on', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      _generateFloor();
      return;
    }

    // enemies chase (greedy)
    for (int i = 0; i < enemies.length; i++) {
      final e = enemies[i];
      int dx = (player.x - e.x).sign;
      int dy = (player.y - e.y).sign;
      Point<int> step = (rand.nextBool())
          ? Point(e.x + dx, e.y)
          : Point(e.x, e.y + dy);
      if (_walkable(step)) {
        enemies[i] = step;
      } else {
        // try orthogonal
        final alt = Point(e.x + dx, e.y + dy);
        if (_walkable(alt)) enemies[i] = alt;
      }
    }

    // combat: if enemy on player tile
    for (int i = enemies.length - 1; i >= 0; i--) {
      if (enemies[i] == player) {
        enemies.removeAt(i);
        hp -= 1;
        score += 3;
      }
    }

    if (hp <= 0) {
      bestDepth = max(bestDepth, depth);
      bestScore = max(bestScore, score);
      _persistBest();
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: GamerTheme.card,
          title: const Text(
            'You fell...',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Depth: $depth    Score: $score\nBest Depth: $bestDepth    Best Score: $bestScore',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      // reset run
      depth = 1;
      score = 0;
      hp = 5;
      _generateFloor();
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neon Roguelike'),
        actions: [
          IconButton(
            tooltip: 'New floor',
            onPressed: () {
              depth += 1;
              _generateFloor();
            },
            icon: const Icon(Icons.stairs),
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focus..requestFocus(),
        onKey: (e) {
          if (e.isKeyPressed(LogicalKeyboardKey.arrowUp) ||
              e.logicalKey == LogicalKeyboardKey.keyW)
            _move(const Point(0, -1));
          if (e.isKeyPressed(LogicalKeyboardKey.arrowDown) ||
              e.logicalKey == LogicalKeyboardKey.keyS)
            _move(const Point(0, 1));
          if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft) ||
              e.logicalKey == LogicalKeyboardKey.keyA)
            _move(const Point(-1, 0));
          if (e.isKeyPressed(LogicalKeyboardKey.arrowRight) ||
              e.logicalKey == LogicalKeyboardKey.keyD)
            _move(const Point(1, 0));
        },
        child: LayoutBuilder(
          builder: (_, c) {
            final cell = (min(
              c.maxWidth / cols,
              (c.maxHeight - 60) / rows,
            )).floorToDouble();
            final w = cell * cols, h = cell * rows;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: w,
                    height: h,
                    decoration: GamerTheme.neonPanel(),
                    padding: const EdgeInsets.all(6),
                    child: Stack(
                      children: [
                        // tiles
                        for (int y = 0; y < rows; y++)
                          for (int x = 0; x < cols; x++)
                            Positioned(
                              left: x * cell,
                              top: y * cell,
                              child: Container(
                                width: cell,
                                height: cell,
                                decoration: BoxDecoration(
                                  color: map[y][x] == 1
                                      ? GamerTheme.card.withOpacity(0.55)
                                      : map[y][x] == 2
                                      ? GamerTheme.neonPurple.withOpacity(0.5)
                                      : GamerTheme.card.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: Colors.white10,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        // stairs glyph
                        for (int y = 0; y < rows; y++)
                          for (int x = 0; x < cols; x++)
                            if (map[y][x] == 2)
                              Positioned(
                                left: x * cell,
                                top: y * cell,
                                child: SizedBox(
                                  width: cell,
                                  height: cell,
                                  child: const Center(
                                    child: Text(
                                      '◆',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                        // enemies
                        ...enemies.map(
                          (e) => Positioned(
                            left: e.x * cell,
                            top: e.y * cell,
                            child: SizedBox(
                              width: cell,
                              height: cell,
                              child: const Center(
                                child: Text(
                                  '👾',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // player
                        Positioned(
                          left: player.x * cell,
                          top: player.y * cell,
                          child: Container(
                            width: cell,
                            height: cell,
                            decoration: BoxDecoration(
                              color: GamerTheme.neonGreen,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 10,
                                  color: GamerTheme.neonGreen,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: GamerTheme.neonPanel(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'HP: $hp',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Text('Depth: $depth'),
                        const SizedBox(width: 16),
                        Text('Score: $score'),
                        const SizedBox(width: 16),
                        Text('BestDepth: $bestDepth  •  Best: $bestScore'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
