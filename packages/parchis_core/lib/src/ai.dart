import 'dart:math';

import 'board.dart';
import 'engine.dart';

/// How well an AI seat picks its move. Offline the player chooses; online
/// rooms and auto-play use [AiLevel.medium].
enum AiLevel {
  /// Random legal move.
  easy,

  /// Avoids bad cells, prefers finishing and captures.
  medium,

  /// Hunts captures above almost everything else.
  hard,
}

/// The token [player] moves after rolling [dice], out of [movable] (never
/// empty). The same choice the app's offline AI and the server's AI seats
/// make.
RulesToken chooseAiMove(
  ParchisEngine engine,
  RulesPlayer player,
  int dice,
  List<RulesToken> movable,
  AiLevel level,
  Random random,
) {
  if (level == AiLevel.easy) return movable[random.nextInt(movable.length)];

  final hard = level == AiLevel.hard;
  final board = engine.board;
  var selected = movable.first;
  var maxPriority = -200;

  for (final token in movable) {
    var priority = 0;
    final target = token.position + dice;

    if (target >= board.finalPosition) {
      priority = 100;
    } else if (target > 0) {
      if (_canCapture(engine, player, target)) priority = hard ? 120 : 90;

      final action = board.getCell(target).action;
      if (action != null) {
        switch (action.type) {
          case BoardActionType.goToStart:
            priority -= 150;
          case BoardActionType.skipTurn:
            priority -= 140;
          case BoardActionType.moveTo when action.targetNumber! < target:
            priority -= 130;
          case BoardActionType.rollAgain:
            priority += 20;
          case BoardActionType.moveTo:
            break;
        }
      }
    }

    // Tie-break: tokens further along go first (hard leans on it more).
    if (priority == 0) {
      priority = 10 +
          token.position +
          (hard ? token.position * 10 ~/ board.finalPosition : 0);
    }

    if (priority > maxPriority) {
      maxPriority = priority;
      selected = token;
    }
  }
  return selected;
}

bool _canCapture(ParchisEngine engine, RulesPlayer player, int target) {
  for (final other in engine.players) {
    if (other.id == player.id) continue;
    for (final t in other.tokens) {
      if (!t.isFinished && t.position == target) return true;
    }
  }
  return false;
}
