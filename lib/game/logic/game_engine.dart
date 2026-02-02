// lib/game/logic/game_engine.dart
import '../models/board.dart';
import '../models/player.dart';
import '../models/cell.dart';
import '../models/board_action.dart';

class GameEngine {
  final Board board;
  final List<Player> players;

  int currentPlayerIndex = 0;
  bool finished = false;

  Player? winner;

  void finishGame(Player player) {
    finished = true;
    winner = player;
  }

  GameEngine({
    required this.board,
    required this.players,
  });

  Player get currentPlayer => players[currentPlayerIndex];

  int rollDice() {
    return 1 + (DateTime.now().millisecondsSinceEpoch % 6);
  }

  void playTurn() {
    if (finished) return;

    final player = currentPlayer;

    if (player.mustSkipTurn) {
      player.consumeSkip();
      nextTurn();
      return;
    }

    final dice = rollDice();

    if (dice == 6) {
      player.consecutiveSixes++;
    } else {
      player.consecutiveSixes = 0;
    }

    if (player.consecutiveSixes == 3) {
      player.resetToStart();
      nextTurn();
      return;
    }

    int newPosition = player.position + dice;

    if (newPosition > board.finalPosition) {
      nextTurn();
      return;
    }

    player.position = newPosition;

    // Colisiones
    for (var other in players) {
      if (other != player && other.position == player.position) {
        other.resetToStart();
      }
    }

    final cell = board.getCell(player.position);

    if (cell.type == CellType.action && cell.action != null) {
      _applyAction(player, cell.action!);
    }

    if (dice != 6) nextTurn();
  }

  void _applyAction(Player player, BoardAction action) {
    switch (action.type) {
      case BoardActionType.goToStart:
        player.resetToStart();
        break;
      case BoardActionType.moveTo:
        player.position = action.targetNumber!;
        break;
      case BoardActionType.skipTurn:
        player.skippedTurns++;
        break;
      case BoardActionType.rollAgain:
      // no hacemos nextTurn para permitir tirar de nuevo
        break;
    }
  }

  void nextTurn() {
    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
  }

}
