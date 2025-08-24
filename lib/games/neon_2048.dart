import 'dart:math';
import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../theme.dart';

class Neon2048Screen extends StatefulWidget {
  const Neon2048Screen({super.key});

  @override
  State<Neon2048Screen> createState() => _Neon2048ScreenState();
}

class _Neon2048ScreenState extends State<Neon2048Screen> {
  List<List<int>> board = List.generate(4, (_) => List.filled(4, 0));
  int score = 0;
  int best = 0;
  final rand = Random();

  @override
  void initState() {
    super.initState();
    final data = ProgressService.read('2048') as Map?;
    if (data != null) {
      final saved = (data['board'] as List?)?.map((r) => List<int>.from(r)).toList();
      if (saved != null && saved.length == 4) {
        board = List<List<int>>.from(saved);
        score = (data['score'] as int?) ?? 0;
      }
      best = (data['best'] as int?) ?? 0;
    }
    if (_emptyTiles().isEmpty) {
      // existing game is valid
    } else if (score == 0) {
      _addRandomTile();
      _addRandomTile();
    }
  }

  Future<void> _persist() async {
    await ProgressService.write('2048', {
      'board': board.map((r) => r.toList()).toList(),
      'score': score,
      'best': best,
    });
  }

  List<Point<int>> _emptyTiles() {
    final list = <Point<int>>[];
    for (int r=0; r<4; r++) {
      for (int c=0; c<4; c++) {
        if (board[r][c] == 0) list.add(Point(r,c));
      }
    }
    return list;
  }

  void _addRandomTile() {
    final empties = _emptyTiles();
    if (empties.isEmpty) return;
    final p = empties[rand.nextInt(empties.length)];
    board[p.x][p.y] = rand.nextDouble() < 0.9 ? 2 : 4;
  }

  bool _moveLeft() {
    bool moved = false;
    for (int r=0; r<4; r++) {
      final row = board[r];
      final nonZero = row.where((v) => v != 0).toList();
      final merged = <int>[];
      for (int i=0; i<nonZero.length; i++) {
        if (i+1 < nonZero.length && nonZero[i] == nonZero[i+1]) {
          final v = nonZero[i]*2;
          merged.add(v);
          score += v;
          i++;
        } else {
          merged.add(nonZero[i]);
        }
      }
      while (merged.length < 4) merged.add(0);
      if (!moved && !_listEq(merged, row)) moved = true;
      board[r] = merged;
    }
    return moved;
  }

  bool _moveRight() {
    for (int r=0; r<4; r++) {
      board[r] = board[r].reversed.toList();
    }
    final m = _moveLeft();
    for (int r=0; r<4; r++) {
      board[r] = board[r].reversed.toList();
    }
    return m;
  }

  bool _moveUp() {
    _transpose();
    final m = _moveLeft();
    _transpose();
    return m;
  }

  bool _moveDown() {
    _transpose();
    final m = _moveRight();
    _transpose();
    return m;
  }

  void _transpose() {
    final b = List.generate(4, (_) => List.filled(4, 0));
    for (int r=0; r<4; r++) for (int c=0; c<4; c++) b[c][r] = board[r][c];
    board = b;
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i=0; i<a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }

  bool _hasMoves() {
    if (_emptyTiles().isNotEmpty) return true;
    // check merges
    for (int r=0; r<4; r++) for (int c=0; c<4; c++) {
      if (r<3 && board[r][c] == board[r+1][c]) return true;
      if (c<3 && board[r][c] == board[r][c+1]) return true;
    }
    return false;
  }

  Future<void> _handleMove(String dir) async {
    bool moved = false;
    switch (dir) {
      case 'L': moved = _moveLeft(); break;
      case 'R': moved = _moveRight(); break;
      case 'U': moved = _moveUp(); break;
      case 'D': moved = _moveDown(); break;
    }
    if (moved) {
      _addRandomTile();
      if (score > best) best = score;
      setState(() {});
      await _persist();
      if (!_hasMoves()) {
        await showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: GamerTheme.card,
          title: const Text('Game Over', style: TextStyle(color: Colors.white)),
          content: Text('Score: $score    Best: $best', style: const TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Colors.white)))],
        ));
      }
    }
  }

  Future<void> _restart() async {
    setState(() {
      board = List.generate(4, (_) => List.filled(4, 0));
      score = 0;
    });
    _addRandomTile(); _addRandomTile();
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2048 Neon'),
        actions: [IconButton(onPressed: _restart, icon: const Icon(Icons.restart_alt))],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            onVerticalDragEnd: (d) {
              if (d.velocity.pixelsPerSecond.dy < 0) { _handleMove('U'); }
              else { _handleMove('D'); }
            },
            onHorizontalDragEnd: (d) {
              if (d.velocity.pixelsPerSecond.dx < 0) { _handleMove('L'); }
              else { _handleMove('R'); }
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      decoration: GamerTheme.neonPanel(),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Score: $score', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Best: $best'),
                          const Text('Swipe or use buttons →'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: GamerTheme.card.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: List.generate(4, (r) => Expanded(
                            child: Row(
                              children: List.generate(4, (c) {
                                final v = board[r][c];
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _tileColor(v),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Center(
                                      child: Text(v==0?'':'$v', style: TextStyle(
                                        fontSize: v>=1024? 28: 32, fontWeight: FontWeight.w900)),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        ElevatedButton(onPressed: ()=>_handleMove('U'), child: const Text('Up')),
                        ElevatedButton(onPressed: ()=>_handleMove('D'), child: const Text('Down')),
                        ElevatedButton(onPressed: ()=>_handleMove('L'), child: const Text('Left')),
                        ElevatedButton(onPressed: ()=>_handleMove('R'), child: const Text('Right')),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _tileColor(int v) {
    if (v==0) return GamerTheme.card.withOpacity(0.35);
    final t = (v == 2) ? const Color(0x2200FFA7)
            : (v == 4) ? const Color(0x227C4DFF)
            : (v <= 16) ? const Color(0x3300FFA7)
            : (v <= 64) ? const Color(0x447C4DFF)
            : (v <= 256) ? const Color(0x6600FFA7)
            : (v <= 1024) ? const Color(0x887C4DFF)
            : const Color(0xAA00FFA7);
    return t;
  }
}
