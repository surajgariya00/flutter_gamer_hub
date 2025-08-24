import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../theme.dart';

class NeonRunnerScreen extends StatefulWidget {
  const NeonRunnerScreen({super.key});

  @override
  State<NeonRunnerScreen> createState() => _NeonRunnerScreenState();
}

class _NeonRunnerScreenState extends State<NeonRunnerScreen> {
  final int lanes = 3;
  int lane = 1; // 0..2
  double playerY = 0.85; // as fraction of height
  double speed = 0.005; // base scroll per tick
  double distance = 0.0; // meters-ish
  double best = 0.0;
  List<_Obstacle> obs = [];
  Timer? _timer;
  final rand = Random();

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('runner') as Map?;
    best = (data?['best'] as num?)?.toDouble() ?? 0.0;
    _start();
  }

  void _start() {
    obs.clear();
    speed = 0.005;
    distance = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick(Timer t) async {
    // spawn
    if (obs.isEmpty || (obs.last.y < 0.4 && rand.nextDouble() < 0.05 + speed)) {
      obs.add(_Obstacle(lane: rand.nextInt(lanes), y: -0.2 - rand.nextDouble()*0.5, size: 0.12));
    }
    // move
    for (final o in obs) {
      o.y += speed;
    }
    obs.removeWhere((o) => o.y > 1.2);

    // speed up slowly
    speed += 0.00002;
    distance += speed * 10.0;

    // collision
    for (final o in obs) {
      if (o.lane == lane) {
        // rectangles intersect?
        final playerTop = playerY - 0.06;
        final playerBottom = playerY + 0.06;
        final obsTop = o.y - o.size/2;
        final obsBottom = o.y + o.size/2;
        if (playerTop < obsBottom && playerBottom > obsTop) {
          // crash!
          _stop();
          if (distance > best) {
            best = distance;
            await ProgressService.write('runner', {'best': best});
          }
          if (!mounted) return;
          await showDialog(context: context, builder: (_) => AlertDialog(
            backgroundColor: GamerTheme.card,
            title: const Text('Crashed!', style: TextStyle(color: Colors.white)),
            content: Text('Distance: ${distance.toStringAsFixed(1)}    Best: ${best.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white70)),
            actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Colors.white)))],
          ));
          _start();
          return;
        }
      }
    }
    if (mounted) setState((){});
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _left() => setState(() => lane = (lane-1).clamp(0, lanes-1));
  void _right() => setState(() => lane = (lane+1).clamp(0, lanes-1));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neon Runner')),
      body: LayoutBuilder(
        builder: (context, c) {
          final laneWidth = c.maxWidth / lanes;
          return Stack(
            children: [
              // lanes glow
              Positioned.fill(
                child: CustomPaint(
                  painter: _LanePainter(lanes: lanes),
                ),
              ),
              // obstacles
              ...obs.map((o) {
                return Positioned(
                  left: o.lane*laneWidth + laneWidth*0.25,
                  top: o.y*c.maxHeight,
                  child: Container(
                    width: laneWidth*0.5,
                    height: c.maxWidth*o.size,
                    decoration: BoxDecoration(
                      color: GamerTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GamerTheme.neonPurple, width: 2),
                      boxShadow: const [BoxShadow(blurRadius: 12, color: GamerTheme.neonPurple)],
                    ),
                  ),
                );
              }),
              // player
              Positioned(
                left: lane*laneWidth + laneWidth*0.25,
                top: playerY*c.maxHeight,
                child: Container(
                  width: laneWidth*0.5,
                  height: laneWidth*0.3,
                  decoration: BoxDecoration(
                    color: GamerTheme.neonGreen,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(blurRadius: 16, color: GamerTheme.neonGreen)],
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
                      Text('Speed: ${(speed*1000).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Dist: ${distance.toStringAsFixed(1)}   Best: ${best.toStringAsFixed(1)}'),
                    ],
                  ),
                ),
              ),
              // controls
              Positioned(
                left: 16, bottom: 18,
                child: ElevatedButton.icon(onPressed: _left, icon: const Icon(Icons.arrow_left), label: const Text('Left')),
              ),
              Positioned(
                right: 16, bottom: 18,
                child: ElevatedButton.icon(onPressed: _right, icon: const Icon(Icons.arrow_right), label: const Text('Right')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Obstacle {
  int lane;
  double y;
  double size;
  _Obstacle({required this.lane, required this.y, required this.size});
}

class _LanePainter extends CustomPainter {
  final int lanes;
  _LanePainter({required this.lanes});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final laneWidth = size.width / lanes;
    for (int i=1; i<lanes; i++) {
      final x = i*laneWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
