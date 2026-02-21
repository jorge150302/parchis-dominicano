import 'dart:math';

import '../models/board.dart';
import '../models/board_action.dart';
import '../models/player.dart';

enum GamePhase {
  idle,
  rolling,
  moving,
  finished,
}

class GameEngine {
  final Board board;
  final List<Player> players;
  final Random _random = Random();
  final List<Player> finishedPlayers = [];

  int _currentPlayerIndex = 0;
  GamePhase phase = GamePhase.idle;

  GameEngine({
    required this.board,
    required this.players,
  });

  Player get currentPlayer => players[_currentPlayerIndex];

  int rollDice() => _random.nextInt(6) + 1;

  void nextTurn() {
    if (players.where((p) => !p.isFinished).length <= 1) {
      phase = GamePhase.finished;
      final lastPlayer = players.firstWhere((p) => !p.isFinished);
      if (!finishedPlayers.contains(lastPlayer)) {
        finishedPlayers.add(lastPlayer);
      }
      return;
    }

    do {
      _currentPlayerIndex = (_currentPlayerIndex + 1) % players.length;
    } while (currentPlayer.isFinished);
  }

  void registerSix(Player player, int diceValue) {
    if (diceValue == 6) {
      player.consecutiveSixes++;
    } else {
      player.consecutiveSixes = 0;
    }
  }

  bool reachedThreeSixes(Player player) => player.consecutiveSixes >= 3;

  void penaltyThreeSixes(Player player) {
    player.resetToStart();
  }

  bool canMove(Player player, int steps) {
    return player.position + steps <= board.finalPosition;
  }

  void stepForward(Player player) {
    if (player.position < board.finalPosition) {
      player.moveBy(1);
      if (player.position == board.finalPosition) {
        player.finish();
        if (!finishedPlayers.contains(player)) {
          finishedPlayers.add(player);
        }
      }
    }
  }

  void stopMoving(Player player) {
    player.isMoving = false;
  }

  void applyCellAction(Player player) {
    final cell = board.getCell(player.position);
    final action = cell.action;

    if (action != null) {
      switch (action.type) {
        case BoardActionType.goToStart:
          player.resetToStart();
          break;
        case BoardActionType.moveTo:
          if (action.targetNumber != null) {
            player.position = action.targetNumber!;
          }
          break;
        case BoardActionType.skipTurn:
          player.addSkip(1);
          break;
        case BoardActionType.rollAgain:
          player.extraTurns++;
          break;
      }
    }
  }

  void resolveCollisions(Player player) {
    if (player.isFinished) return;

    final playersInCell = players.where((p) => p != player && p.position == player.position).toList();

    for (final otherPlayer in playersInCell) {
      otherPlayer.resetToStart();
    }
  }
}
