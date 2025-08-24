import 'package:flutter/material.dart';
import 'package:flutter_gamer_hub/games/cyber_snake.dart';
import 'package:flutter_gamer_hub/games/neon_breakout.dart';
import 'package:flutter_gamer_hub/games/neon_candy_crush.dart';
import 'package:flutter_gamer_hub/games/neon_raycaster.dart';
import 'package:flutter_gamer_hub/games/neon_roguelike.dart';
import 'package:flutter_gamer_hub/games/tron_lightcycles.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme.dart';
import 'models/game.dart';
import 'widgets/game_card.dart';
import 'services/progress_service.dart';
import 'games/tictactoe.dart';
import 'games/memory_match.dart';
import 'games/neon_runner.dart';
import 'games/space_blaster.dart';
import 'games/neon_2048.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await ProgressService.init();
  runApp(const GamerHubApp());
}

class GamerHubApp extends StatelessWidget {
  const GamerHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Gamer Hub',
      theme: GamerTheme.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final List<GameDefinition> _games = [
    GameDefinition(
      id: 'tictactoe',
      name: 'Tic-Tac-Toe',
      description: 'Classic duel. Local progress & scores saved.',
      icon: Icons.grid_3x3_rounded,
      build: (ctx) => const TicTacToeScreen(),
    ),
    GameDefinition(
      id: 'candy',
      name: 'Neon Candy Crush',
      description:
          'Match-3 with combos & cascades. Drag or click to swap. Hive saves.',
      icon: Icons.casino_rounded,
      build: (ctx) => const NeonCandyCrushScreen(),
    ),
    GameDefinition(
      id: 'memory',
      name: 'Memory Match',
      description: 'Flip cards, remember pairs. Beat your moves!',
      icon: Icons.style_rounded,
      build: (ctx) => const MemoryMatchScreen(),
    ),
    GameDefinition(
      id: 'runner',
      name: 'Neon Runner',
      description: 'Endless lanes, dodge obstacles, chase insane speed.',
      icon: Icons.bolt_rounded,
      build: (ctx) => const NeonRunnerScreen(),
    ), // import 'games/neon_breakout.dart',
    GameDefinition(
      id: 'breakout',
      name: 'Neon Breakout',
      description:
          'Arcade brick breaker. Arrows/A-D. Saves best score & level.',
      icon: Icons.auto_awesome,
      build: (ctx) => const NeonBreakoutScreen(),
    ),
    GameDefinition(
      id: 'tron',
      name: 'Neon Lightcycles',
      description: 'Local 2P TRON. WASD vs Arrows. Trails, crashes, Hive wins.',
      icon: Icons.flash_on_rounded,
      build: (ctx) => const TronLightcyclesScreen(),
    ),
    GameDefinition(
      id: 'rogue',
      name: 'Neon Roguelike',
      description: 'Procedural dungeons. Enemies chase. Floors & score saved.',
      icon: Icons.auto_awesome_motion,
      build: (ctx) => const NeonRoguelikeScreen(),
    ),
    GameDefinition(
      id: 'ray',
      name: 'Neon Raycaster',
      description: 'Pseudo-3D maze in Flutter Web. Best time saved.',
      icon: Icons.blur_on_rounded,
      build: (ctx) => const NeonRaycasterScreen(),
    ),

    GameDefinition(
      id: 'snake',
      name: 'Cyber Snake',
      description: 'Wrap-around neon snake. Arrows/WASD. Hive best score.',
      icon: Icons.auto_graph_rounded,
      build: (ctx) => const CyberSnakeScreen(),
    ),

    GameDefinition(
      id: 'blaster',
      name: 'Space Blaster',
      description: 'Top-down shooter. Blast waves, rack up combos.',
      icon: Icons.rocket_launch_rounded,
      build: (ctx) => const SpaceBlasterScreen(),
    ),
    GameDefinition(
      id: '2048',
      name: '2048 Neon',
      description: 'Swipe, merge, ascend to 2048 and beyond.',
      icon: Icons.grid_view_rounded,
      build: (ctx) => const Neon2048Screen(),
    ),
  ];

  String _search = '';

  @override
  Widget build(BuildContext context) {
    final visible = _games
        .where(
          (g) =>
              g.name.toLowerCase().contains(_search) ||
              g.description.toLowerCase().contains(_search) ||
              g.id.toLowerCase().contains(_search),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Flutter Gamer Hub")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Hero Panel
            Container(
              decoration: GamerTheme.neonPanel(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome, Dev!",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your browser-based arcade. Add your own games and we'll save each game's progress locally using Hive.",
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: "Search games...",
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => _search = v.toLowerCase().trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showHowToAddDialog(context),
                        icon: const Icon(Icons.add_box),
                        label: const Text("Add New Game"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Games grid (responsive)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int cols = 1;
                  if (constraints.maxWidth >= 1200)
                    cols = 4;
                  else if (constraints.maxWidth >= 900)
                    cols = 3;
                  else if (constraints.maxWidth >= 600)
                    cols = 2;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final game = visible[i];
                      return GameCard(
                        game: game,
                        onPlay: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: game.build)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHowToAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Your Game"),
        content: const SingleChildScrollView(
          child: Text(
            "1) Create a new file in lib/games/your_game.dart\n"
            "2) Implement a Widget screen for your game.\n"
            "3) Use ProgressService.read/write('yourGameId', ...) to persist any local progress.\n"
            "4) Add a GameDefinition to _games in lib/main.dart.\n\n"
            "Tip: Keep your progress values to primitives, lists, and maps to avoid Hive adapters.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
