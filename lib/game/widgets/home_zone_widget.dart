import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend_parchis/service/prefs_service.dart'; 
import '../models/player.dart';
import '../logic/game_controller.dart';
import '../logic/game_engine.dart';
import 'board_widget.dart';

class HomeZoneWidget extends StatelessWidget {
  final Player player;

  const HomeZoneWidget({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isTurnOfThisZone = controller.currentPlayer.id == player.id;

    final bool isMe = controller.isOnline 
        ? player.id == PrefsService.playerId 
        : true;

    final tokensAtHome = player.tokens.where((t) => t.position == 0 && !t.isFinished).toList();
    final baseColor = _getPlayerColor(player.index);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isTurnOfThisZone 
            ? baseColor.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurnOfThisZone ? baseColor : Colors.transparent,
          width: 2,
        ),
        boxShadow: isTurnOfThisZone ? [
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
          // ❌ El título "TU TURNO" se ha movido a _PlayerCornerWidget para integrar el modo Auto
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              ...tokensAtHome.map((token) {
                final bool isSelectable = controller.engine.phase == GamePhase.choosing_token &&
                    isTurnOfThisZone &&
                    isMe &&
                    controller.movableTokenIds.contains(token.id);

                return TokenWidget(
                  asset: player.tokenAsset,
                  isSelectable: isSelectable,
                  size: 20,
                  onTap: isSelectable ? () => controller.selectToken(token.id) : null,
                );
              }),
            ],
          ),
        ],
      ),
    );

    if (isTurnOfThisZone) {
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
