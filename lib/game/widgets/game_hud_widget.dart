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
      ignoring: true, 
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                  "Fase",
                  engine.phase.name.toUpperCase().replaceAll('_', ' '),
                  _getPhaseColor(engine.phase),
                ),
              ],
            ),
            
            // ✅ Mostrar si hay turnos extra acumulados
            if (player.extraTurns > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    "¡TIENES ${player.extraTurns} TURNO(S) EXTRA!",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),

            const Spacer(),

            if (engine.phase == GamePhase.finished)
               const Center(child: Text("PARTIDA FINALIZADA", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Color _getPhaseColor(GamePhase phase) {
    switch (phase) {
      case GamePhase.idle: return Colors.grey;
      case GamePhase.rolling: return Colors.blue;
      case GamePhase.choosing_token: return Colors.orange;
      case GamePhase.moving: return Colors.green;
      case GamePhase.finished: return Colors.red;
    }
  }

  Widget _infoChip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}
