import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/game_controller.dart';
import '../logic/game_engine.dart';

class GameHudWidget extends StatelessWidget {
  const GameHudWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final engine = controller.engine;

    final player = controller.currentPlayer;

    return IgnorePointer(
      ignoring: true, // HUD no bloquea toques del tablero
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// =============================
            /// 🔝 TOP INFO BAR
            /// =============================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoChip(
                  "Turno",
                  player.name,
                  Colors.orange,
                ),
                _infoChip(
                  "Dado",
                  controller.diceValue.toString(),
                  Colors.blue,
                ),
                _infoChip(
                  "Estado",
                  engine.phase.name.toUpperCase(),
                  Colors.purple,
                ),
              ],
            ),

            const Spacer(),

            /// =============================
            /// 🏆 WINNER OVERLAY
            /// =============================
            if (engine.phase == GamePhase.finished && engine.finishedPlayers.isNotEmpty)
              _winnerCard(engine.finishedPlayers.first.name),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // COMPONENTES
  // =====================================================

  Widget _infoChip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _winnerCard(String name) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🏆 GANADOR",
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
