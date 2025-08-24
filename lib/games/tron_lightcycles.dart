// lib/games/tron_lightcycles.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/progress_service.dart';

class TronLightcyclesScreen extends StatefulWidget {
  const TronLightcyclesScreen({super.key});
  @override
  State<TronLightcyclesScreen> createState() => _TronLightcyclesScreenState();
}

class _TronLightcyclesScreenState extends State<TronLightcyclesScreen> {
  static const int cols = 36;
  static const int rows = 24;
  static const Duration step = Duration(milliseconds: 80);

  final FocusNode _focus = FocusNode();
  Timer? _timer;
  bool running = true;

  // P1 = left start, moves right; P2 = right start, moves left
  List<Point<int>> p1Trail = [];
  List<Point<int>> p2Trail = [];
  Point<int> p1Dir = const Point(1, 0);
  Point<int> p2Dir = const Point(-1, 0);

  int p1Wins = 0, p2Wins = 0;
  final rand = Random();

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('tron') as Map?;
    p1Wins = (data?['p1Wins'] as int?) ?? 0;
    p2Wins = (data?['p2Wins'] as int?) ?? 0;
    _newRound();
    _timer = Timer.periodic(step, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _newRound() {
    p1Trail = [Point(3, rows ~/ 2)];
    p2Trail = [Point(cols - 4, rows ~/ 2)];
    p1Dir = const Point(1, 0);
    p2Dir = const Point(-1, 0);
  }

  Future<void> _saveWins() async {
    await ProgressService.write('tron', {'p1Wins': p1Wins, 'p2Wins': p2Wins});
  }

  void _turnP1(Point<int> d) {
    final cur = p1Trail.length > 1
        ? Point(
            p1Trail.last.x - p1Trail[p1Trail.length - 2].x,
            p1Trail.last.y - p1Trail[p1Trail.length - 2].y,
          )
        : p1Dir;
    if (cur.x == -d.x && cur.y == -d.y) return; // no 180°
    p1Dir = d;
  }

  void _turnP2(Point<int> d) {
    final cur = p2Trail.length > 1
        ? Point(
            p2Trail.last.x - p2Trail[p2Trail.length - 2].x,
            p2Trail.last.y - p2Trail[p2Trail.length - 2].y,
          )
        : p2Dir;
    if (cur.x == -d.x && cur.y == -d.y) return;
    p2Dir = d;
  }

  bool _hit(Point<int> p, List<Point<int>> a, List<Point<int>> b) {
    if (p.x < 0 || p.x >= cols || p.y < 0 || p.y >= rows) return true;
    if (a.contains(p) || b.contains(p)) return true;
    return false;
  }

  Future<void> _tick() async {
    if (!mounted || !running) return;
    // next heads
    final p1Next = Point(p1Trail.last.x + p1Dir.x, p1Trail.last.y + p1Dir.y);
    final p2Next = Point(p2Trail.last.x + p2Dir.x, p2Trail.last.y + p2Dir.y);

    final p1Crash = _hit(p1Next, p1Trail, p2Trail);
    final p2Crash = _hit(p2Next, p2Trail, p1Trail);

    if (p1Crash && p2Crash) {
      // draw
      running = false;
      await _postRound('Draw! No points awarded.');
      return;
    }
    if (p1Crash) {
      running = false;
      p2Wins++;
      await _saveWins();
      await _postRound('P2 wins the round!');
      return;
    }
    if (p2Crash) {
      running = false;
      p1Wins++;
      await _saveWins();
      await _postRound('P1 wins the round!');
      return;
    }

    p1Trail.add(p1Next);
    p2Trail.add(p2Next);
    setState(() {});
  }

  Future<void> _postRound(String msg) async {
    setState(() {});
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GamerTheme.card,
        title: const Text('Round Over', style: TextStyle(color: Colors.white)),
        content: Text(
          '$msg\n\nScore:  P1 $p1Wins  —  P2 $p2Wins',
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
    _newRound();
    running = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neon Lightcycles (2P)'),
        actions: [
          IconButton(
            tooltip: running ? 'Pause' : 'Resume',
            onPressed: () => setState(() => running = !running),
            icon: Icon(running ? Icons.pause : Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Restart round',
            onPressed: () {
              running = true;
              _newRound();
              setState(() {});
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focus..requestFocus(),
        onKey: (e) {
          // P1 WASD
          if (e.isKeyPressed(LogicalKeyboardKey.keyW))
            _turnP1(const Point(0, -1));
          if (e.isKeyPressed(LogicalKeyboardKey.keyS))
            _turnP1(const Point(0, 1));
          if (e.isKeyPressed(LogicalKeyboardKey.keyA))
            _turnP1(const Point(-1, 0));
          if (e.isKeyPressed(LogicalKeyboardKey.keyD))
            _turnP1(const Point(1, 0));
          // P2 arrows
          if (e.isKeyPressed(LogicalKeyboardKey.arrowUp))
            _turnP2(const Point(0, -1));
          if (e.isKeyPressed(LogicalKeyboardKey.arrowDown))
            _turnP2(const Point(0, 1));
          if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft))
            _turnP2(const Point(-1, 0));
          if (e.isKeyPressed(LogicalKeyboardKey.arrowRight))
            _turnP2(const Point(1, 0));
          // pause/resume + restart
          if (e.logicalKey == LogicalKeyboardKey.space)
            setState(() => running = !running);
          if (e.logicalKey == LogicalKeyboardKey.keyR) {
            running = true;
            _newRound();
            setState(() {});
          }
        },
        child: LayoutBuilder(
          builder: (_, c) {
            final cell = (min(
              c.maxWidth / cols,
              c.maxHeight / rows,
            )).floorToDouble();
            final w = cell * cols;
            final h = cell * rows;
            return Center(
              child: Container(
                width: w,
                height: h,
                decoration: GamerTheme.neonPanel(),
                padding: const EdgeInsets.all(6),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(w, h),
                      painter: _Grid(cell: cell),
                    ),
                    // trails
                    ...p1Trail.map(
                      (p) => Positioned(
                        left: p.x * cell,
                        top: p.y * cell,
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: GamerTheme.neonGreen,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 8,
                                color: GamerTheme.neonGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ...p2Trail.map(
                      (p) => Positioned(
                        left: p.x * cell,
                        top: p.y * cell,
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: GamerTheme.neonPurple,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 8,
                                color: GamerTheme.neonPurple,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // HUD
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Container(
                        decoration: GamerTheme.neonPanel(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'P1 (WASD): $p1Wins',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(running ? 'Running' : 'Paused'),
                            Text(
                              'P2 (Arrows): $p2Wins',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Grid extends CustomPainter {
  final double cell;
  _Grid({required this.cell});
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
  bool shouldRepaint(covariant _Grid oldDelegate) => false;
}
