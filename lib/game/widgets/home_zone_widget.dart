import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/player.dart';
import '../logic/game_controller.dart';
import '../logic/game_engine.dart';
import 'board_widget.dart'; // Importamos para usar TokenWidget

class HomeZoneWidget extends StatelessWidget {
  final Player player;

  const HomeZoneWidget({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isCurrentPlayer = controller.currentPlayer.id == player.id;
    
    final tokensAtHome = player.tokens.where((t) => t.position == 0).toList();
    final tokensFinished = player.tokens.where((t) => t.isFinished).toList();

    // Color temático basado en el asset o índice si no hay un color explícito
    final baseColor = _getPlayerColor(player.index);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
            ? baseColor.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlayer ? baseColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: isCurrentPlayer ? [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentPlayer)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: const Text(
                "TU TURNO",
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ).animate(onPlay: (c) => c.repeat())
               .fadeIn(duration: 600.ms)
               .then()
               .fadeOut(duration: 600.ms),
            ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              ...tokensAtHome.map((token) {
                final bool isSelectable = controller.engine.phase == GamePhase.choosing_token &&
                    isCurrentPlayer &&
                    controller.movableTokenIds.contains(token.id);

                return TokenWidget(
                  asset: player.tokenAsset,
                  isSelectable: isSelectable,
                  size: 20,
                  onTap: isSelectable ? () => controller.selectToken(token.id) : null,
                );
              }),
              
              ...tokensFinished.map((t) =>
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                  .animate().scale(curve: Curves.bounceOut)
              ),
            ],
          ),
        ],
      ),
    );

    if (isCurrentPlayer) {
      return content.animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 2.seconds,
          color: baseColor.withValues(alpha: 0.2),
        );
    }

    return content;
  }

  Color _getPlayerColor(int index) {
    switch (index) {
      case 0: return Colors.red;
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 3: return Colors.yellow;
      default: return Colors.orange;
    }
  }
}
