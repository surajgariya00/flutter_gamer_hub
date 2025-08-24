// lib/games/neon_raycaster.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/progress_service.dart';

class NeonRaycasterScreen extends StatefulWidget {
  const NeonRaycasterScreen({super.key});
  @override
  State<NeonRaycasterScreen> createState() => _NeonRaycasterScreenState();
}

class _NeonRaycasterScreenState extends State<NeonRaycasterScreen> {
  // Map: 0 empty, 1 wall, 2 goal
  late List<List<int>> map;
  int mw = 16, mh = 12;

  // Player
  double px = 2.5, py = 2.5; // position in map units
  double dir = 0; // radians
  double fov = pi / 3;

  Timer? _timer;
  final FocusNode _focus = FocusNode();
  int bestTimeMs = 0;
  DateTime _started = DateTime.now();
  final rand = Random();

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('raycaster') as Map?;
    bestTimeMs = (data?['bestTimeMs'] as int?) ?? 0;
    _newMaze();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted) setState(() {}); // repaint
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _newMaze() {
    // simple randomized maze: outer walls + random boxes
    map = List.generate(mh, (_) => List.filled(mw, 1));
    for (int y = 1; y < mh - 1; y++) {
      for (int x = 1; x < mw - 1; x++) {
        map[y][x] = rand.nextDouble() < 0.78 ? 0 : 1;
      }
    }
    // carve a corridor from start to goal
    int x = 1, y = 1;
    map[y][x] = 0;
    while (x < mw - 2 || y < mh - 2) {
      if (rand.nextBool() && x < mw - 2)
        x++;
      else if (y < mh - 2)
        y++;
      map[y][x] = 0;
    }
    // goal
    map[mh - 2][mw - 2] = 2;
    // player
    px = 1.5;
    py = 1.5;
    dir = 0;
    _started = DateTime.now();
  }

  void _move(double dx, double dy) {
    final nx = px + dx, ny = py + dy;
    if (map[ny.floor().clamp(0, mh - 1)][nx.floor().clamp(0, mw - 1)] != 1) {
      px = nx;
      py = ny;
    }
    // win?
    if ((px - (mw - 2 + 0.5)).abs() < 0.5 &&
        (py - (mh - 2 + 0.5)).abs() < 0.5) {
      final elapsed = DateTime.now().difference(_started).inMilliseconds;
      if (bestTimeMs == 0 || elapsed < bestTimeMs) {
        bestTimeMs = elapsed;
        ProgressService.write('raycaster', {'bestTimeMs': bestTimeMs});
      }
      _newMaze();
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(_started).inMilliseconds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neon Raycaster'),
        actions: [
          IconButton(onPressed: _newMaze, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focus..requestFocus(),
        onKey: (e) {
          final speed = 0.08;
          final rot = 0.12;
          if (e.isKeyPressed(LogicalKeyboardKey.keyW)) {
            _move(cos(dir) * speed, sin(dir) * speed);
          }
          if (e.isKeyPressed(LogicalKeyboardKey.keyS)) {
            _move(-cos(dir) * speed, -sin(dir) * speed);
          }
          if (e.isKeyPressed(LogicalKeyboardKey.keyA)) {
            _move(-sin(dir) * speed, cos(dir) * speed); // strafe left
          }
          if (e.isKeyPressed(LogicalKeyboardKey.keyD)) {
            _move(sin(dir) * speed, -cos(dir) * speed); // strafe right
          }
          if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
            setState(() => dir -= rot);
          }
          if (e.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
            setState(() => dir += rot);
          }
          if (e.logicalKey == LogicalKeyboardKey.keyR) _newMaze();
        },
        child: LayoutBuilder(
          builder: (_, c) {
            final w = min(c.maxWidth, 1000.0);
            final h = min(c.maxHeight - 10, 620.0);
            return Center(
              child: Container(
                width: w,
                height: h,
                decoration: GamerTheme.neonPanel(),
                padding: const EdgeInsets.all(10),
                child: CustomPaint(
                  painter: _RayPainter(
                    map: map,
                    mw: mw,
                    mh: mh,
                    px: px,
                    py: py,
                    dir: dir,
                    fov: fov,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
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
                                'Time: ${elapsed / 1000.0}s',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'W/S: Move  •  A/D: Strafe  •  ←/→: Turn  •  R: New',
                              ),
                              Text(
                                'Best: ${bestTimeMs == 0 ? "--" : "${bestTimeMs / 1000.0}s"}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RayPainter extends CustomPainter {
  final List<List<int>> map;
  final int mw, mh;
  final double px, py, dir, fov;

  _RayPainter({
    required this.map,
    required this.mw,
    required this.mh,
    required this.px,
    required this.py,
    required this.dir,
    required this.fov,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F1A);
    canvas.drawRect(Offset.zero & size, bg);

    // sky & floor
    final sky = Paint()..color = const Color(0xFF111726);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), sky);
    final floor = Paint()..color = const Color(0xFF0C1322);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
      floor,
    );

    final rays = size.width.toInt();
    for (int x = 0; x < rays; x++) {
      final camX =
          (2 * x / rays - 1) *
          (fov / (pi / 3)); // normalized -1..1 scaled by FOV
      final rayDir = dir + camX * (fov / 2);
      // DDA
      double rx = px;
      double ry = py;
      final step = 0.02;
      double dist = 0.0;
      bool hit = false;
      int side = 0; // 0 x, 1 y
      int cell = 0;
      for (int i = 0; i < 1000; i++) {
        rx += cos(rayDir) * step;
        ry += sin(rayDir) * step;
        dist += step;
        final mx = rx.floor().clamp(0, mw - 1);
        final my = ry.floor().clamp(0, mh - 1);
        cell = map[my][mx];
        if (cell == 1 || cell == 2) {
          hit = true;
          // crude side detection
          final fx = rx - rx.floor();
          final fy = ry - ry.floor();
          side = (fx.abs() < 0.02 || fx > 0.98)
              ? 0
              : (fy.abs() < 0.02 || fy > 0.98)
              ? 1
              : side;
          break;
        }
      }
      if (!hit) continue;

      final corrected = dist * cos(camX * (fov / 2)); // remove fisheye
      final lineH = (size.height / corrected).clamp(2.0, size.height);
      final y0 = (size.height - lineH) / 2;
      final rect = Rect.fromLTWH(x.toDouble(), y0, 1, lineH);

      // coloring
      Color base = (cell == 2) ? GamerTheme.neonGreen : GamerTheme.neonPurple;
      double shade = (side == 1) ? 0.65 : 0.9;
      final wall = Paint()..color = base.withOpacity(shade);
      canvas.drawRect(rect, wall);
    }
    // mini 2D map overlay
    final mini = min(size.width, size.height) * 0.18;
    final cw = mini / mw;
    final ch = mini / mh;
    final p = Paint()
      ..color = const Color(0x55FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(8, 8, mini, mini),
      Paint()..color = const Color(0x2200FFA7),
    );
    for (int y = 0; y < mh; y++) {
      for (int x = 0; x < mw; x++) {
        if (map[y][x] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(8 + x * cw, 8 + y * ch, cw - 0.5, ch - 0.5),
            p,
          );
        } else if (map[y][x] == 2) {
          canvas.drawCircle(
            Offset(8 + (x + 0.5) * cw, 8 + (y + 0.5) * ch),
            cw * 0.35,
            Paint()..color = GamerTheme.neonGreen,
          );
        }
      }
    }
    canvas.drawCircle(
      Offset(8 + px * cw, 8 + py * ch),
      cw * 0.3,
      Paint()..color = GamerTheme.neonPurple,
    );
  }

  @override
  bool shouldRepaint(covariant _RayPainter old) =>
      px != old.px || py != old.py || dir != old.dir || map != old.map;
}
