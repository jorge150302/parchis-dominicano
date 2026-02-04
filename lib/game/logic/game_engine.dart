// lib/game/logic/game_engine.dart

import 'dart:math';

import '../models/board.dart';
import '../models/player.dart';
import '../models/cell.dart';
import '../models/board_action.dart';

/// =======================================================
/// 🎯 SOLO REGLAS DE JUEGO (sin animaciones ni delays)
/// El Controller maneja UI y timing.
/// =======================================================

enum GamePhase {
  idle,
  rolling,
  moving,
  finished,
}

class GameEngine {
  final Board board;
  final List<Player> players;

  GameEngine({
    required this.board,
    required this.players,
  });

  // =====================================================
  // STATE
  // =====================================================

  int currentPlayerIndex = 0;
  bool finished = false;
  Player? winner;

  GamePhase phase = GamePhase.idle;

  final Random _random = Random();

  // =====================================================
  // GETTERS
  // =====================================================

  Player get currentPlayer => players[currentPlayerIndex];

  // =====================================================
  // 🎲 DICE
  // =====================================================

  int rollDice() => _random.nextInt(6) + 1;

  // =====================================================
  // 🎯 TURN CONTROL
  // =====================================================

  void nextTurn() {
    if (finished) return;

    currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    phase = GamePhase.idle;
  }

  // =====================================================
  // 🏁 FINISH
  // =====================================================

  void finishGame(Player player) {
    finished = true;
    winner = player;
    phase = GamePhase.finished;

    player.finish(); // 🆕 marca jugador como terminado
  }

  // =====================================================
  // 🚶 MOVEMENT RULES
  // =====================================================

  /// devuelve true si puede moverse
  bool canMove(Player player, int steps) {
    if (player.isFinished) return false;

    return player.position + steps <= board.finalPosition;
  }

  /// mueve una casilla (usado por controller animado)
  void stepForward(Player player) {
    if (player.isFinished) return;

    player.isMoving = true;
    player.moveBy(1);

    // 🏁 llegó a meta
    if (player.position == board.finalPosition) {
      finishGame(player);
    }
  }

  /// llamado cuando termina animación
  void stopMoving(Player player) {
    player.isMoving = false;
  }

  // =====================================================
  // 💥 COLLISIONS
  // =====================================================

  void resolveCollisions(Player current) {
    for (final other in players) {
      if (other == current) continue;
      if (other.isFinished) continue;

      if (other.position == current.position) {
        other.resetToStart();
      }
    }
  }

  // =====================================================
  // 🟧 CELL ACTIONS
  // =====================================================

  void applyCellAction(Player player) {
    if (player.isFinished) return;

    final Cell cell = board.getCell(player.position);

    if (cell.action == null) return;

    _applyAction(player, cell.action!);
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
        player.addSkip(1); // 🆕 helper
        break;

      case BoardActionType.rollAgain:
      // el controller decide no cambiar turno
        break;
    }
  }

  // =====================================================
  // 🔥 RULE HELPERS
  // =====================================================

  void registerSix(Player player, int dice) {
    if (dice == 6) {
      player.consecutiveSixes++;
    } else {
      player.consecutiveSixes = 0;
    }
  }

  bool reachedThreeSixes(Player player) {
    return player.consecutiveSixes >= 3;
  }

  /// castigo por 3 seises
  void penaltyThreeSixes(Player player) {
    player.resetToStart();
    nextTurn();
  }
}
