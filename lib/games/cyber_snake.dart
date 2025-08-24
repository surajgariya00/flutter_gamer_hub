// lib/games/cyber_snake.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/progress_service.dart';

class CyberSnakeScreen extends StatefulWidget {
  const CyberSnakeScreen({super.key});
  @override
  State<CyberSnakeScreen> createState() => _CyberSnakeScreenState();
}

class _CyberSnakeScreenState extends State<CyberSnakeScreen> {
  static const int rows = 22;
  static const int cols = 22;
  static const Duration tick = Duration(milliseconds: 90);

  final rand = Random();
  final FocusNode _focusNode = FocusNode();

  List<Point<int>> snake = [];
  Point<int> dir = const Point(1, 0); // moving right
  Point<int> food = const Point(10, 10);
  Timer? _timer;
  int score = 0;
  int best = 0;
  bool paused = false;
  bool alive = true;
  int level = 1;

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('snake') as Map?;
    best = (data?['best'] as int?) ?? 0;
    _newGame();
  }

  void _newGame() {
    snake = [const Point(5, 10), const Point(6, 10), const Point(7, 10)];
    dir = const Point(1, 0);
    score = 0;
    level = 1;
    alive = true;
    paused = false;
    food = _spawnFood();
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => _step());
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Point<int> _spawnFood() {
    while (true) {
      final p = Point(rand.nextInt(cols), rand.nextInt(rows));
      if (!snake.contains(p)) return p;
    }
  }

  void _togglePause() {
    if (!alive) return;
    setState(() => paused = !paused);
  }

  void _step() async {
    if (!mounted || paused || !alive) return;

    // Speed up a bit with score
    final delayFactor = max(0.6, 1.0 - (score / 200.0));
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = Timer.periodic(tick * delayFactor, (_) => _step());
    }

    final head = snake.last;
    var nx = (head.x + dir.x) % cols;
    var ny = (head.y + dir.y) % rows;
    if (nx < 0) nx += cols;
    if (ny < 0) ny += rows;
    final next = Point(nx, ny);

    if (snake.contains(next)) {
      // crash into yourself
      alive = false;
      if (score > best) {
        best = score;
        await ProgressService.write('snake', {'best': best});
      }
      setState(() {});
      await _showGameOver();
      _newGame();
      return;
    }

    snake.add(next);

    if (next == food) {
      score += 5;
      if (score % 25 == 0) level += 1; // soft levels for vibes
      food = _spawnFood();
    } else {
      snake.removeAt(0); // move forward
    }
    setState(() {});
  }

  Future<void> _showGameOver() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GamerTheme.card,
        title: const Text('Game Over', style: TextStyle(color: Colors.white)),
        content: Text(
          'Score: $score\nBest:  $best\nLevel: $level',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _turn(Point<int> d) {
    // prevent 180° reversal
    if (snake.length > 1) {
      final h = snake.last;
      final b = snake[snake.length - 2];
      final cur = Point(h.x - b.x, h.y - b.y);
      if (cur.x == -d.x && cur.y == -d.y) return;
    }
    setState(() => dir = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cyber Snake'),
        actions: [
          IconButton(
            tooltip: paused ? 'Resume' : 'Pause',
            onPressed: _togglePause,
            icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          ),
          IconButton(
            tooltip: 'Restart',
            onPressed: _newGame,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode..requestFocus(),
        onKey: (e) {
          if (e.isKeyPressed(LogicalKeyboardKey.arrowUp) ||
              e.logicalKey == LogicalKeyboardKey.keyW) {
            _turn(const Point(0, -1));
          } else if (e.isKeyPressed(LogicalKeyboardKey.arrowDown) ||
              e.logicalKey == LogicalKeyboardKey.keyS) {
            _turn(const Point(0, 1));
          } else if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft) ||
              e.logicalKey == LogicalKeyboardKey.keyA) {
            _turn(const Point(-1, 0));
          } else if (e.isKeyPressed(LogicalKeyboardKey.arrowRight) ||
              e.logicalKey == LogicalKeyboardKey.keyD) {
            _turn(const Point(1, 0));
          } else if (e.logicalKey == LogicalKeyboardKey.space) {
            _togglePause();
          }
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final cell = (min(c.maxWidth, c.maxHeight) / max(rows, cols))
                .floorToDouble();
            final boardW = cell * cols;
            final boardH = cell * rows;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: boardW,
                    height: boardH,
                    decoration: GamerTheme.neonPanel(),
                    padding: const EdgeInsets.all(6),
                    child: Stack(
                      children: [
                        // Grid glow
                        CustomPaint(
                          size: Size(boardW, boardH),
                          painter: _GridPainter(cell: cell),
                        ),
                        // Food
                        Positioned(
                          left: food.x * cell,
                          top: food.y * cell,
                          child: Container(
                            width: cell,
                            height: cell,
                            decoration: BoxDecoration(
                              color: GamerTheme.neonPurple,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 12,
                                  color: GamerTheme.neonPurple,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Snake
                        ...snake.map(
                          (p) => Positioned(
                            left: p.x * cell,
                            top: p.y * cell,
                            child: Container(
                              width: cell,
                              height: cell,
                              decoration: BoxDecoration(
                                color: GamerTheme.neonGreen,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 10,
                                    color: GamerTheme.neonGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: GamerTheme.neonPanel(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Score: $score',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        Text('Best: $best'),
                        const SizedBox(width: 16),
                        Text('Level: $level'),
                        const SizedBox(width: 16),
                        Text(paused ? 'Paused' : 'Running'),
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

class _GridPainter extends CustomPainter {
  final double cell;
  _GridPainter({required this.cell});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x22FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
