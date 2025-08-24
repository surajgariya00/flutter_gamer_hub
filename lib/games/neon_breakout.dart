// lib/games/neon_breakout.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/progress_service.dart';

class NeonBreakoutScreen extends StatefulWidget {
  const NeonBreakoutScreen({super.key});
  @override
  State<NeonBreakoutScreen> createState() => _NeonBreakoutScreenState();
}

class _NeonBreakoutScreenState extends State<NeonBreakoutScreen> {
  final FocusNode _focus = FocusNode();
  Timer? _timer;
  double dt = 1 / 60;

  int rows = 5;
  int cols = 10;
  late List<List<bool>> bricks;

  int score = 0;
  int bestScore = 0;
  int bestLevel = 1;
  int lives = 3;
  int level = 1;

  double paddleX = 0.5; // 0..1 center
  double paddleW = 0.16; // fraction of width
  double ballX = 0.5, ballY = 0.7;
  double vx = 220, vy = -260; // pixels/sec
  bool running = false;

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('breakout') as Map?;
    bestScore = (data?['bestScore'] as int?) ?? 0;
    bestLevel = (data?['bestLevel'] as int?) ?? 1;
    _resetLevel();
    _loop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _resetLevel() {
    bricks = List.generate(rows, (_) => List.generate(cols, (_) => true));
    ballX = 0.5;
    ballY = 0.7;
    vx = 200 + level * 20;
    vy = (-(240 + level * 25)) as double;
    paddleW = 0.18 - min(0.10, level * 0.01);
    running = false;
  }

  void _loop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!running) return;
      setState(() {}); // trigger LayoutBuilder to get pixels
    });
  }

  void _start() => setState(() => running = true);
  void _pause() => setState(() => running = false);

  void _moveLeft() =>
      setState(() => paddleX = max(paddleW / 2, paddleX - 0.03));
  void _moveRight() =>
      setState(() => paddleX = min(1 - paddleW / 2, paddleX + 0.03));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neon Breakout'),
        actions: [
          IconButton(
            onPressed: () => _resetAll(),
            icon: const Icon(Icons.restart_alt),
          ),
          IconButton(
            onPressed: () => running ? _pause() : _start(),
            icon: Icon(running ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focus..requestFocus(),
        onKey: (e) {
          if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft) ||
              e.logicalKey == LogicalKeyboardKey.keyA)
            _moveLeft();
          if (e.isKeyPressed(LogicalKeyboardKey.arrowRight) ||
              e.logicalKey == LogicalKeyboardKey.keyD)
            _moveRight();
          if (e.logicalKey == LogicalKeyboardKey.space)
            running ? _pause() : _start();
        },
        child: LayoutBuilder(
          builder: (context, c) {
            // Playfield with padding
            final w = min(c.maxWidth, 1000.0);
            final h = min(c.maxHeight - 40, 700.0);
            final pad = 16.0;
            final fieldW = w - pad * 2;
            final fieldH = h - pad * 2;

            // advance ball if running
            if (running) {
              final px = ballX * fieldW;
              final py = ballY * fieldH;
              var nx = px + vx * dt;
              var ny = py + vy * dt;

              // walls
              if (nx < 0) {
                nx = 0;
                vx = vx.abs();
              }
              if (nx > fieldW) {
                nx = fieldW;
                vx = -vx.abs();
              }
              if (ny < 0) {
                ny = 0;
                vy = vy.abs();
              }

              // paddle
              final paddlePx = paddleX * fieldW;
              final paddleY = fieldH - 22;
              final half = paddleW * fieldW / 2;
              if (ny >= paddleY - 10 && ny <= paddleY + 10) {
                if (nx >= paddlePx - half && nx <= paddlePx + half && vy > 0) {
                  // reflect with angle based on hit position
                  final t = ((nx - paddlePx) / half).clamp(-1.0, 1.0);
                  final speed = sqrt(vx * vx + vy * vy) * 1.02; // tiny speed-up
                  final angle = (-pi / 3) * t; // -60..60 deg from vertical
                  vx = speed * sin(angle);
                  vy = -speed * cos(angle);
                  ny = paddleY - 11;
                }
              }

              // bricks
              final brickW = fieldW / cols;
              final brickH = 20.0;
              if (ny < rows * brickH + 8) {
                final bx = (nx / brickW).floor().clamp(0, cols - 1);
                final by = (ny / brickH).floor().clamp(0, rows - 1);
                if (bricks[by][bx]) {
                  bricks[by][bx] = false;
                  score += 10 + level;
                  // bounce: decide by which side we hit
                  final localX = (nx % brickW);
                  final localY = (ny % brickH);
                  if (localX < 4 || localX > brickW - 4) {
                    vx = -vx;
                  } else {
                    vy = -vy;
                  }
                }
              }

              // bottom (lose life)
              if (ny > fieldH + 10) {
                lives -= 1;
                running = false;
                if (lives <= 0) {
                  _gameOver();
                } else {
                  ballX = 0.5;
                  ballY = 0.7;
                  vx = 220;
                  vy = -260;
                }
              } else {
                ballX = nx / fieldW;
                ballY = ny / fieldH;
              }

              // next level
              final anyLeft = bricks.any((r) => r.any((b) => b));
              if (!anyLeft) {
                level += 1;
                rows = min(9, rows + 1);
                _resetLevel();
              }
            }

            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: Container(
                  decoration: GamerTheme.neonPanel(),
                  padding: EdgeInsets.all(pad),
                  child: Stack(
                    children: [
                      // bricks
                      ...List.generate(rows, (r) => r).expand(
                        (r) => List.generate(cols, (c2) => c2).map((c2) {
                          if (!bricks[r][c2]) return const SizedBox.shrink();
                          final brickW = fieldW / cols;
                          const brickH = 20.0;
                          final x = c2 * brickW;
                          final y = r * brickH;
                          final color = r.isEven
                              ? GamerTheme.neonPurple
                              : GamerTheme.neonGreen;
                          return Positioned(
                            left: x,
                            top: y,
                            child: Container(
                              width: brickW - 4,
                              height: brickH - 4,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(blurRadius: 12, color: color),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                      // paddle
                      Positioned(
                        left: paddleX * fieldW - (paddleW * fieldW / 2),
                        top: fieldH - 22,
                        child: Container(
                          width: paddleW * fieldW,
                          height: 12,
                          decoration: BoxDecoration(
                            color: GamerTheme.neonGreen,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 14,
                                color: GamerTheme.neonGreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ball
                      Positioned(
                        left: ballX * fieldW - 7,
                        top: ballY * fieldH - 7,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: GamerTheme.neonPurple,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                blurRadius: 14,
                                color: GamerTheme.neonPurple,
                              ),
                            ],
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
                                'Score: $score',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Lives: $lives'),
                              Text(
                                'Level: $level  •  Best Lvl: $bestLevel  •  Best: $bestScore',
                              ),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _moveLeft,
                                    child: const Icon(Icons.chevron_left),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () =>
                                        running ? _pause() : _start(),
                                    child: Icon(
                                      running ? Icons.pause : Icons.play_arrow,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _moveRight,
                                    child: const Icon(Icons.chevron_right),
                                  ),
                                ],
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

  Future<void> _gameOver() async {
    if (score > bestScore) bestScore = score;
    if (level > bestLevel) bestLevel = level;
    await ProgressService.write('breakout', {
      'bestScore': bestScore,
      'bestLevel': bestLevel,
    });
    setState(() {});
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GamerTheme.card,
        title: const Text('Game Over', style: TextStyle(color: Colors.white)),
        content: Text(
          'Score: $score\nBest:  $bestScore\nLevel: $level (Best: $bestLevel)',
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
    // reset full run
    score = 0;
    lives = 3;
    level = 1;
    rows = 5;
    _resetLevel();
  }

  void _resetAll() {
    score = 0;
    lives = 3;
    level = 1;
    rows = 5;
    _resetLevel();
    setState(() {});
  }
}
