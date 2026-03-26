import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/player.dart';
import '../logic/game_controller.dart';
import '../logic/game_engine.dart';

class HomeZoneWidget extends StatelessWidget {
  final Player player;

  const HomeZoneWidget({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    
    final tokensAtHome = player.tokens.where((t) => t.position == 0).toList();
    final tokensFinished = player.tokens.where((t) => t.isFinished).toList();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          ...tokensAtHome.map((token) {
            final bool isSelectable = controller.engine.phase == GamePhase.choosing_token &&
                controller.currentPlayer.id == player.id &&
                controller.movableTokenIds.contains(token.id);

            Widget tWidget = Image.asset(player.tokenAsset, width: 20, height: 20);

            if (isSelectable) {
              return GestureDetector(
                onTap: () => controller.selectToken(token.id),
                child: tWidget,
              );
            }
            return tWidget;
          }),
          
          ...tokensFinished.map((t) =>
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
              .animate().scale(curve: Curves.bounceOut)
          ),
        ],
      ),
    );
  }
}
