import 'dart:math';
import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../theme.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  // 0 = empty, 1 = X, 2 = O
  List<int> board = List.filled(9, 0);
  int currentPlayer = 1;
  int xScore = 0;
  int oScore = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = ProgressService.read('tictactoe') as Map?;
    if (data != null) {
      final b = (data['board'] as List?)?.cast<int>() ?? List.filled(9, 0);
      final cp = (data['currentPlayer'] as int?) ?? 1;
      final xs = (data['xScore'] as int?) ?? 0;
      final os = (data['oScore'] as int?) ?? 0;
      setState(() {
        board = b;
        currentPlayer = cp;
        xScore = xs;
        oScore = os;
      });
    }
  }

  Future<void> _save() async {
    await ProgressService.write('tictactoe', {
      'board': board,
      'currentPlayer': currentPlayer,
      'xScore': xScore,
      'oScore': oScore,
    });
  }

  int? _winner() {
    const wins = [
      [0,1,2],[3,4,5],[6,7,8],
      [0,3,6],[1,4,7],[2,5,8],
      [0,4,8],[2,4,6]
    ];
    for (final w in wins) {
      if (board[w[0]] != 0 && board[w[0]] == board[w[1]] && board[w[1]] == board[w[2]]) {
        return board[w[0]];
      }
    }
    if (!board.contains(0)) return 0; // draw
    return null;
  }

  void _tap(int i) async {
    if (board[i] != 0) return;
    setState(() => board[i] = currentPlayer);
    final w = _winner();
    if (w == null) {
      setState(() => currentPlayer = (currentPlayer == 1) ? 2 : 1);
      await _save();
      return;
    }
    if (w == 1) xScore++;
    if (w == 2) oScore++;

    await _save();
    await showDialog(context: context, builder: (ctx) {
      final msg = (w == 0) ? "It's a draw!" : (w == 1 ? "X wins!" : "O wins!");
      return AlertDialog(
        backgroundColor: GamerTheme.card,
        title: const Text("Game Over", style: TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          )
        ],
      );
    });
    setState(() {
      board = List.filled(9, 0);
      currentPlayer = Random().nextBool() ? 1 : 2;
    });
    await _save();
  }

  Future<void> _resetScores() async {
    setState(() { xScore = 0; oScore = 0; });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tic-Tac-Toe"),
        actions: [
          IconButton(
            tooltip: "Reset scores",
            onPressed: _resetScores,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: GamerTheme.neonPanel(),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _score('X', xScore),
                    _score('O', oScore),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  itemCount: 9,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8
                  ),
                  itemBuilder: (context, i) {
                    final v = board[i];
                    return InkWell(
                      onTap: () => _tap(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: GamerTheme.card.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.6)),
                        ),
                        child: Center(
                          child: Text(
                            v == 0 ? "" : (v == 1 ? "X" : "O"),
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text("Turn: ${currentPlayer == 1 ? "X" : "O"}"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _score(String label, int score) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("$score", style: const TextStyle(fontSize: 20)),
      ],
    );
  }
}
