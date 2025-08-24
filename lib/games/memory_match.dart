import 'dart:math';
import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../theme.dart';

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  final List<String> _emojis = ["🎮","🚀","🧩","🐍","👾","🪐","⚡","💎"];
  late List<String> _deck; // duplicated + shuffled = 16
  Set<int> _matched = {};
  List<int> _open = [];
  int _moves = 0;
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _newDeck([int? seed]) {
    final s = seed ?? DateTime.now().millisecondsSinceEpoch;
    final rand = Random(s);
    final base = List<String>.from(_emojis)..shuffle(rand);
    final pairs = (base.take(8).toList());
    _deck = [...pairs, ...pairs]..shuffle(rand);
    _matched = {};
    _open = [];
    _moves = 0;
    _seed = s;
  }

  Future<void> _load() async {
    final data = ProgressService.read('memory') as Map?;
    if (data == null) {
      setState(() => _newDeck());
      return;
    }
    setState(() {
      _seed = (data['seed'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
      _newDeck(_seed);
      _matched = Set<int>.from((data['matched'] as List?) ?? []);
      _open = List<int>.from((data['open'] as List?) ?? []);
      _moves = (data['moves'] as int?) ?? 0;
    });
  }

  Future<void> _save() async {
    await ProgressService.write('memory', {
      'seed': _seed,
      'matched': _matched.toList(),
      'open': _open,
      'moves': _moves,
    });
  }

  Future<void> _tap(int i) async {
    if (_matched.contains(i) || _open.contains(i)) return;
    setState(() => _open.add(i));
    if (_open.length == 2) {
      _moves++;
      await Future.delayed(const Duration(milliseconds: 350));
      final a = _open[0], b = _open[1];
      if (_deck[a] == _deck[b]) {
        setState(() {
          _matched.addAll([a, b]);
          _open.clear();
        });
      } else {
        setState(() => _open.clear());
      }
      await _save();

      if (_matched.length == _deck.length) {
        await _save();
        await showDialog(context: context, builder: (ctx) {
          return AlertDialog(
            backgroundColor: GamerTheme.card,
            title: const Text("You win!", style: TextStyle(color: Colors.white)),
            content: Text("Moves: $_moves", style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      }
    }
    await _save();
  }

  Future<void> _restart() async {
    setState(() => _newDeck());
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Memory Match"),
        actions: [
          IconButton(onPressed: _restart, icon: const Icon(Icons.restart_alt)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                decoration: GamerTheme.neonPanel(),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Moves: $_moves"),
                    Text("Matched: ${_matched.length}/${_deck.length}"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: 16,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8
                  ),
                  itemBuilder: (context, i) {
                    final isOpen = _open.contains(i) || _matched.contains(i);
                    return InkWell(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isOpen ? GamerTheme.card : GamerTheme.card.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isOpen ? GamerTheme.neonGreen : Colors.white24,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            isOpen ? _deck[i] : "❓",
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
