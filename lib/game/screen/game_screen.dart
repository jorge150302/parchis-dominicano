import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/game_controller.dart';
import '../models/player.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/home_zone_widget.dart';

class GameScreen extends StatefulWidget {
  final int playerCount;

  const GameScreen({
    super.key,
    required this.playerCount,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final controller = context.read<GameController>();

      final tokens = [
        'assets/tokens/red.png',
        'assets/tokens/blue.png',
        'assets/tokens/green.png',
        'assets/tokens/yellow.png',
      ];

      final players = List.generate(
        widget.playerCount,
        (i) => Player(
          id: '${i + 1}',
          name: 'Jugador ${i + 1}',
          tokenAsset: tokens[i % tokens.length],
        ),
      );

      controller.setPlayers(players);
    });
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar partida'),
        content: const Text('¿Deseas terminar la partida? Si sales ahora, la partida finalizará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit && mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/menu_background.png',
                fit: BoxFit.cover,
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade700,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.brown.shade900,
                          width: 6,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 18,
                            color: Colors.black45,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: BoardWidget(
                        board: controller.engine.board,
                        players: controller.players,
                      ),
                    ),
                  ),
                  ..._buildPlayers(controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlayers(GameController controller) {
    final players = controller.players;
    const positions = [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ];

    return List.generate(players.length, (i) {
      final player = players[i];
      return Align(
        alignment: positions[i % positions.length],
        child: _PlayerCornerWidget(player: player),
      );
    });
  }
}

class _PlayerCornerWidget extends StatelessWidget {
  final Player player;

  const _PlayerCornerWidget({
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isTurn = controller.currentPlayer.id == player.id;
    final rollingThisDice = controller.rollingDice && isTurn;
    final canRoll = isTurn && !controller.rollingDice;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isTurn ? Colors.orange : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(player.tokenAsset, width: 22, height: 22),
                const SizedBox(width: 6),
                Text(
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: canRoll ? controller.rollDice : null,
            child: Opacity(
              opacity: isTurn ? 1 : 0.35,
              child: DiceWidget(
                key: ValueKey(player.id),
                value: controller.diceValue,
                rolling: rollingThisDice,
                style: const DiceStyle(
                  sides: 6,
                  assetPath: 'assets/dice/classic',
                  size: 60,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          HomeZoneWidget(player: player),
        ],
      ),
    );
  }
}
