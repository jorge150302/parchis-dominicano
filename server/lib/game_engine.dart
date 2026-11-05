import 'dart:math';

import 'package:parchis_core/parchis_core.dart';
import 'package:parchis_server/models/player.dart';

export 'package:parchis_core/parchis_core.dart';

enum GamePhase {
  idle,
  rolling,
  choosingToken,
  moving,
  finished,
}

/// A room's match: the shared rules engine plus what only the server tracks
/// (the protocol phase, the dice and the last roll).
class GameEngine extends ParchisEngine<Player> {
  GameEngine({
    required super.board,
    required super.players,
    super.rules,
    this.boardId = 'medium',
    Random? random,
  }) : _random = random ?? Random();

  final Random _random;

  /// Catalog id of [board], sent to clients so they draw the same board.
  final String boardId;

  GamePhase phase = GamePhase.idle;
  int lastDiceValue = 0;

  Player get currentPlayer => current;

  /// Finishing order (alias of [finishOrder]).
  List<Player> get finishedPlayers => finishOrder;

  int rollDice() {
    lastDiceValue = _random.nextInt(6) + 1;
    return lastDiceValue;
  }

  bool canMoveAnyToken(Player player, int steps) =>
      movableTokens(player, steps).isNotEmpty;

  /// The token an AI or auto-play seat moves for [lastDiceValue], or null
  /// when none can move. Online seats play at [AiLevel.medium].
  Token? aiMove() {
    final movable = movableTokens(currentPlayer, lastDiceValue);
    if (movable.isEmpty) return null;
    return chooseAiMove(
      this,
      currentPlayer,
      lastDiceValue,
      movable,
      AiLevel.medium,
      _random,
    ) as Token;
  }
}
