import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/game_controller.dart';
import '../models/player.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart'; // ✅ nuevo widget de sprites

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

    /// ⚡ crear jugadores SOLO una vez
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    return Scaffold(
      body: Stack(
        children: [
          /// 🌄 background
          Positioned.fill(
            child: Image.asset(
              'assets/images/menu_background.png',
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                /// =====================================
                /// 🟫 TABLERO
                /// =====================================
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

                /// =====================================
                /// 👥 JUGADORES EN ESQUINAS
                /// =====================================
                ..._buildPlayers(controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// =================================================
  /// 📍 Posiciones parchís (4 esquinas)
  /// =================================================
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

/// =================================================
/// 🎲 Player Corner (nombre + ficha + dado sprite)
/// =================================================
class _PlayerCornerWidget extends StatelessWidget {
  final Player player;

  const _PlayerCornerWidget({required this.player});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    final isTurn = controller.currentPlayer.id == player.id;
    final canRoll = isTurn && !controller.rollingDice;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// =====================================
          /// 🎟️ NOMBRE + FICHA (highlight naranja)
          /// =====================================
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isTurn ? Colors.orange : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isTurn
                  ? const [
                BoxShadow(
                  color: Colors.orangeAccent,
                  blurRadius: 8,
                )
              ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(player.tokenAsset, width: 22, height: 22),
                const SizedBox(width: 6),
                Text(
                  player.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          /// =====================================
          /// 🎲 DADO (sprites, no 3D fake)
          /// SOLO gira el del turno
          /// =====================================
          GestureDetector(
            onTap: canRoll ? controller.rollDice : null,
            child: Opacity(
              opacity: isTurn ? 1 : 0.35,
              child: DiceWidget(
                value: controller.diceValue,
                rolling: controller.rollingDice && isTurn,
                style: const DiceStyle(
                  sides: 6,
                  assetPath: 'assets/dice/classic',
                  size: 60,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
