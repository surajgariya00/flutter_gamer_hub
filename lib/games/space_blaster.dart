import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../theme.dart';

class SpaceBlasterScreen extends StatefulWidget {
  const SpaceBlasterScreen({super.key});

  @override
  State<SpaceBlasterScreen> createState() => _SpaceBlasterScreenState();
}

class _SpaceBlasterScreenState extends State<SpaceBlasterScreen> {
  double playerX = 0.5; // 0..1
  double playerY = 0.85;
  final List<_Bullet> bullets = [];
  final List<_Enemy> enemies = [];
  Timer? _timer;
  final rand = Random();
  int score = 0;
  int best = 0;
  double spawnTimer = 0.0;

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('blaster') as Map?;
    best = (data?['best'] as int?) ?? 0;
    _start();
  }

  void _start() {
    bullets.clear();
    enemies.clear();
    score = 0;
    spawnTimer = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick(Timer t) async {
    // spawn enemies
    spawnTimer += 0.016;
    if (spawnTimer > max(0.2, 1.0 - score/200.0)) {
      spawnTimer = 0.0;
      enemies.add(_Enemy(x: rand.nextDouble(), y: -0.1, speed: 0.003 + rand.nextDouble()*0.004));
    }

    // move bullets
    for (final b in bullets) b.y -= 0.01;
    bullets.removeWhere((b) => b.y < -0.1);

    // move enemies
    for (final e in enemies) e.y += e.speed;

    // collisions
    for (final b in List<_Bullet>.from(bullets)) {
      for (final e in List<_Enemy>.from(enemies)) {
        if ((b.x-e.x).abs() < 0.04 && (b.y-e.y).abs() < 0.06) {
          bullets.remove(b);
          enemies.remove(e);
          score += 5;
          break;
        }
      }
    }

    // check player collision
    for (final e in enemies) {
      if ((e.x - playerX).abs() < 0.06 && (e.y - playerY).abs() < 0.06) {
        _stop();
        if (score > best) {
          best = score;
          await ProgressService.write('blaster', {'best': best});
        }
        if (!mounted) return;
        await showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: GamerTheme.card,
          title: const Text('You were hit!', style: TextStyle(color: Colors.white)),
          content: Text('Score: $score    Best: $best', style: const TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Colors.white)))],
        ));
        _start();
        return;
      }
    }

    enemies.removeWhere((e) => e.y > 1.2);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _moveLeft() => setState(() => playerX = (playerX - 0.04).clamp(0.05, 0.95));
  void _moveRight() => setState(() => playerX = (playerX + 0.04).clamp(0.05, 0.95));
  void _shoot() => setState(() => bullets.add(_Bullet(x: playerX, y: playerY-0.05)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Space Blaster')),
      body: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              // stars (simple parallax dots)
              Positioned.fill(child: CustomPaint(painter: _StarfieldPainter(time: DateTime.now().millisecondsSinceEpoch))),
              // enemies
              ...enemies.map((e) => Positioned(
                left: e.x*c.maxWidth-16, top: e.y*c.maxHeight-16,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: GamerTheme.neonPurple,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(blurRadius: 16, color: GamerTheme.neonPurple)],
                  ),
                ),
              )),
              // bullets
              ...bullets.map((b) => Positioned(
                left: b.x*c.maxWidth-3, top: b.y*c.maxHeight-12,
                child: Container(width: 6, height: 12, color: GamerTheme.neonGreen),
              )),
              // player
              Positioned(
                left: playerX*c.maxWidth-18, top: playerY*c.maxHeight-14,
                child: Container(
                  width: 36, height: 28,
                  decoration: BoxDecoration(
                    color: GamerTheme.neonGreen,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [BoxShadow(blurRadius: 14, color: GamerTheme.neonGreen)],
                  ),
                ),
              ),
              // HUD
              Positioned(
                left: 16, right: 16, top: 12,
                child: Container(
                  decoration: GamerTheme.neonPanel(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Score: $score', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Best: $best'),
                    ],
                  ),
                ),
              ),
              // controls
              Positioned(left: 12, bottom: 16, child: ElevatedButton.icon(onPressed: _moveLeft, icon: const Icon(Icons.arrow_left), label: const Text('Left'))),
              Positioned(right: 12, bottom: 16, child: ElevatedButton.icon(onPressed: _moveRight, icon: const Icon(Icons.arrow_right), label: const Text('Right'))),
              Positioned(right: 12, bottom: 72, child: ElevatedButton.icon(onPressed: _shoot, icon: const Icon(Icons.bolt), label: const Text('Shoot'))),
            ],
          );
        },
      ),
    );
  }
}

class _Bullet {
  double x, y;
  _Bullet({required this.x, required this.y});
}

class _Enemy {
  double x, y, speed;
  _Enemy({required this.x, required this.y, required this.speed});
}

class _StarfieldPainter extends CustomPainter {
  final int time;
  _StarfieldPainter({required this.time});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x33FFFFFF);
    final t = time/1000.0;
    for (int i=0; i<200; i++) {
      final x = (i*73 % size.width) + (t*10 % 1);
      final y = ((i*91 + time*0.05) % size.height);
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), i%3==0 ? 1.8 : 1.0, paint);
    }
  }
  @override bool shouldRepaint(covariant _StarfieldPainter old) => true;
}
