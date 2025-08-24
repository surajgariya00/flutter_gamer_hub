// lib/games/neon_candy_crush.dart  (v3: robust desktop/web dragging)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // for DragStartBehavior
import '../theme.dart';
import '../services/progress_service.dart';

class NeonCandyCrushScreen extends StatefulWidget {
  const NeonCandyCrushScreen({super.key});
  @override
  State<NeonCandyCrushScreen> createState() => _NeonCandyCrushScreenState();
}

class _NeonCandyCrushScreenState extends State<NeonCandyCrushScreen> {
  static const int rows = 8;
  static const int cols = 8;
  static const int types = 6;
  static const int baseMoves = 25;

  final rand = Random();
  late List<List<int>> board; // [row][col]
  Point<int>? sel;
  Set<Point<int>> fading = {};
  bool animating = false;
  bool blinkInvalid = false;

  int score = 0, best = 0, moves = baseMoves, level = 1;
  int seed = DateTime.now().millisecondsSinceEpoch;

  // Drag state (robust)
  Point<int>? dragCell;
  Offset dragAccum = Offset.zero; // accumulate delta from onPanUpdate
  bool dragDidSwap = false;

  @override
  void initState() {
    super.initState();
    _newRun(newSeed: false);
  }

  Future<void> _save() async {
    await ProgressService.write('candy', {
      'best': best,
      'level': level,
      'score': score,
      'moves': moves,
      'seed': seed,
      'board': board.map((r) => r.toList()).toList(),
    });
  }

  // ---------- RUN / BOARD ----------
  void _newRun({bool newSeed = true}) {
    final data = ProgressService.read('candy') as Map?;
    if (!newSeed && data != null) {
      try {
        best = (data['best'] as int?) ?? 0;
        level = (data['level'] as int?) ?? 1;
        score = (data['score'] as int?) ?? 0;
        moves = (data['moves'] as int?) ?? baseMoves;
        seed = (data['seed'] as int?) ?? seed;
        final grid = (data['board'] as List?)
            ?.map((r) => List<int>.from(r))
            .toList();
        if (grid != null && grid.length == rows && grid.first.length == cols) {
          board = grid;
          _removeAllMatchesNoScore();
          if (!_existsAnyMove()) _reshuffleNoMatchesEnsureMove();
          setState(() {});
          return;
        }
      } catch (_) {}
    }
    if (newSeed) seed = DateTime.now().millisecondsSinceEpoch ^ level;
    final rng = Random(seed);
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => rng.nextInt(types)),
    );
    _removeAllMatchesNoScore();
    if (!_existsAnyMove()) _reshuffleNoMatchesEnsureMove();
    score = 0;
    moves = baseMoves + min(10, level);
    sel = null;
    _save();
    setState(() {});
  }

  void _removeAllMatchesNoScore() {
    int tries = 0;
    while (_findMatches().isNotEmpty && tries < 120) {
      _shuffleFlat();
      tries++;
    }
  }

  void _reshuffleNoMatchesEnsureMove() {
    int tries = 0;
    do {
      _shuffleFlat();
      _removeAllMatchesNoScore();
      tries++;
    } while (!_existsAnyMove() && tries < 250);
  }

  void _shuffleFlat() {
    final flat = <int>[];
    for (final r in board) flat.addAll(r);
    flat.shuffle(rand);
    for (int i = 0; i < rows * cols; i++) {
      board[i ~/ cols][i % cols] = flat[i];
    }
  }

  bool _inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  // ---------- MATCH / CASCADE ----------
  Set<Point<int>> _findMatches() {
    final matched = <Point<int>>{};
    // rows
    for (int r = 0; r < rows; r++) {
      int run = 1;
      for (int c = 1; c <= cols; c++) {
        final cur = (c < cols) ? board[r][c] : -99;
        final prev = board[r][c - 1];
        if (c < cols && cur == prev)
          run++;
        else {
          if (prev != -99 && run >= 3) {
            for (int k = c - run; k < c; k++) matched.add(Point(r, k));
          }
          run = 1;
        }
      }
    }
    // cols
    for (int c = 0; c < cols; c++) {
      int run = 1;
      for (int r = 1; r <= rows; r++) {
        final cur = (r < rows) ? board[r][c] : -99;
        final prev = board[r - 1][c];
        if (r < rows && cur == prev)
          run++;
        else {
          if (prev != -99 && run >= 3) {
            for (int k = r - run; k < r; k++) matched.add(Point(k, c));
          }
          run = 1;
        }
      }
    }
    return matched;
  }

  bool _existsAnyMove() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (c + 1 < cols) {
          _swap(Point(r, c), Point(r, c + 1));
          final ok = _findMatches().isNotEmpty;
          _swap(Point(r, c), Point(r, c + 1));
          if (ok) return true;
        }
        if (r + 1 < rows) {
          _swap(Point(r, c), Point(r + 1, c));
          final ok = _findMatches().isNotEmpty;
          _swap(Point(r, c), Point(r + 1, c));
          if (ok) return true;
        }
      }
    }
    return false;
  }

  void _swap(Point<int> a, Point<int> b) {
    final t = board[a.x][a.y];
    board[a.x][a.y] = board[b.x][b.y];
    board[b.x][b.y] = t;
  }

  Future<void> _trySwap(Point<int> a, Point<int> b) async {
    if (animating) return;
    if (!_inBounds(a.x, a.y) || !_inBounds(b.x, b.y)) return;
    if (!((a.x == b.x && (a.y - b.y).abs() == 1) ||
        (a.y == b.y && (a.x - b.x).abs() == 1))) {
      sel = b;
      setState(() {});
      return;
    }
    _swap(a, b);
    final m = _findMatches();
    if (m.isEmpty) {
      _swap(a, b);
      blinkInvalid = true;
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 140));
      blinkInvalid = false;
      setState(() {});
      return;
    }
    sel = null;
    await _cascadeWithScoring();
  }

  Future<void> _cascadeWithScoring() async {
    animating = true;
    int combo = 0;
    while (true) {
      final m = _findMatches();
      if (m.isEmpty) break;
      combo++;
      fading = m;
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 140));

      // clear and score
      for (final p in m) board[p.x][p.y] = -1;
      score += m.length * 10 * combo;

      // gravity + fill
      for (int c = 0; c < cols; c++) {
        int write = rows - 1;
        for (int r = rows - 1; r >= 0; r--) {
          if (board[r][c] != -1) {
            board[write][c] = board[r][c];
            write--;
          }
        }
        final rng = Random(seed ^ (c << 7) ^ combo);
        for (int r = write; r >= 0; r--) board[r][c] = rng.nextInt(types);
      }

      fading = {};
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 80));
    }

    moves = (moves - 1).clamp(0, 9999);
    if (score > best) best = score;
    if (!_existsAnyMove()) _reshuffleNoMatchesEnsureMove();
    await _save();

    if (moves == 0) {
      await _showLevelEnd();
      level += 1;
      _newRun(newSeed: true);
    }

    animating = false;
    setState(() {});
  }

  Future<void> _showLevelEnd() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GamerTheme.card,
        title: const Text(
          'Out of Moves',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Score: $score   •   Best: $best   •   Level: $level',
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

  // ---------- INPUT ----------
  void _tapCell(Point<int> p) {
    if (animating) return;
    if (sel == null) {
      sel = p;
      setState(() {});
    } else {
      final a = sel!;
      sel = null;
      _trySwap(a, p);
    }
  }

  void _dragStartAt(Point<int> p) {
    dragCell = p;
    dragAccum = Offset.zero;
    dragDidSwap = false;
  }

  void _dragUpdate(Offset delta) {
    if (dragCell == null || dragDidSwap || animating) return;
    dragAccum += delta; // accumulate movement
    const threshold = 10.0; // low threshold feels snappy on desktop/web
    if (dragAccum.distance < threshold) return;

    Point<int> target = dragCell!;
    if (dragAccum.dx.abs() > dragAccum.dy.abs()) {
      target = Point(target.x, target.y + (dragAccum.dx > 0 ? 1 : -1));
    } else {
      target = Point(target.x + (dragAccum.dy > 0 ? 1 : -1), target.y);
    }
    dragDidSwap = true;
    _trySwap(dragCell!, target);
  }

  void _dragEnd() {
    dragCell = null;
    dragAccum = Offset.zero;
    dragDidSwap = false;
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neon Candy Crush'),
        actions: [
          IconButton(
            tooltip: 'New Game',
            onPressed: () {
              level = 1;
              _newRun(newSeed: true);
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final cell = (min(c.maxWidth, c.maxHeight - 120) / max(rows, cols))
              .floorToDouble();
          final w = cell * cols, h = cell * rows;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                      const SizedBox(width: 14),
                      Text('Best: $best'),
                      const SizedBox(width: 14),
                      Text('Moves: $moves'),
                      const SizedBox(width: 14),
                      Text('Level: $level'),
                      const SizedBox(width: 14),
                      const Text('Click two tiles or drag to swap'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: w,
                  height: h,
                  decoration: GamerTheme.neonPanel(),
                  padding: const EdgeInsets.all(6),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(w, h),
                        painter: _GridPainter(cell: cell),
                      ),
                      for (int r = 0; r < rows; r++)
                        for (int c2 = 0; c2 < cols; c2++) _tile(r, c2, cell),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(int r, int c, double cell) {
    final v = board[r][c];
    final p = Point(r, c);
    final selected = sel == p;
    final isFading = fading.contains(p);
    final base = _candyColor(v);

    return Positioned(
      left: c * cell,
      top: r * cell,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // <- ensures we catch mouse drags
        dragStartBehavior: DragStartBehavior.down, // <- start drag instantly
        onTap: () => _tapCell(p),
        onPanStart: (_) => _dragStartAt(p),
        onPanUpdate: (d) =>
            _dragUpdate(d.delta), // <- accumulate reliable delta
        onPanEnd: (_) => _dragEnd(),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: isFading ? 0.0 : 1.0,
          child: Container(
            width: cell,
            height: cell,
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? GamerTheme.neonGreen
                    : (blinkInvalid ? Colors.redAccent : Colors.white10),
                width: selected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: base.withOpacity(0.7),
                  blurRadius: selected ? 16 : 10,
                  spreadRadius: selected ? 1.4 : 0.6,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withOpacity(0.95),
                  Colors.white.withOpacity(0.10),
                ],
              ),
            ),
            child: Center(child: _glyph(v)),
          ),
        ),
      ),
    );
  }

  Color _candyColor(int v) {
    switch (v) {
      case 0:
        return GamerTheme.neonPurple.withOpacity(0.85);
      case 1:
        return GamerTheme.neonGreen.withOpacity(0.85);
      case 2:
        return const Color(0xFF00C2FF).withOpacity(0.85);
      case 3:
        return const Color(0xFFFF4D8D).withOpacity(0.85);
      case 4:
        return const Color(0xFFFFD166).withOpacity(0.90);
      default:
        return const Color(0xFF8AFF66).withOpacity(0.85);
    }
  }

  Widget _glyph(int v) {
    const style = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      color: Colors.white,
    );
    switch (v) {
      case 0:
        return const Text('◆', style: style);
      case 1:
        return const Text('●', style: style);
      case 2:
        return const Text('▲', style: style);
      case 3:
        return const Text('★', style: style);
      case 4:
        return const Text('■', style: style);
      default:
        return const Text('✦', style: style);
    }
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
