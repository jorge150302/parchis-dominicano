import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/cell.dart';
import '../models/board_action.dart';
import 'game_engine.dart';

class GameController extends ChangeNotifier {
  final GameEngine engine;

  bool rollingDice = false;
  int diceValue = 1;

  GameController(this.engine);

  List<Player> get players => engine.players;
  Player get currentPlayer => engine.currentPlayer;

  // =====================================================
  // PLAYERS
  // =====================================================

  void setPlayers(List<Player> newPlayers) {
    engine.players
      ..clear()
      ..addAll(newPlayers);

    notifyListeners();
  }

  // =====================================================
  // DICE
  // =====================================================

  Future<void> rollDice() async {
    if (rollingDice || engine.finished) return;

    final player = currentPlayer;

    /// ⏭️ saltar turno
    if (player.mustSkipTurn) {
      player.consumeSkip();
      engine.nextTurn();
      notifyListeners();
      return;
    }

    rollingDice = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    diceValue = engine.rollDice();

    rollingDice = false;
    notifyListeners();

    /// 🔥 regla 3 seises
    if (diceValue == 6) {
      player.consecutiveSixes++;
    } else {
      player.consecutiveSixes = 0;
    }

    if (player.consecutiveSixes == 3) {
      player.resetToStart();
      engine.nextTurn();
      notifyListeners();
      return;
    }

    await _moveStepByStep(diceValue);
  }

  // =====================================================
  // MOVIMIENTO PASO A PASO (SIN BoardKey)
  // =====================================================

  Future<void> _moveStepByStep(int steps) async {
    final player = currentPlayer;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 280));

      if (player.position < engine.board.finalPosition) {
        player.position++; // 🔥 mover 1 casilla
        notifyListeners();
      }
    }

    /// 🎯 llegó a FIN
    if (player.position >= engine.board.finalPosition) {
      engine.finishGame(player);
      notifyListeners();
      return;
    }

    await _applyBoardAction(player);

    _checkCollisions(player);

    if (diceValue != 6) {
      engine.nextTurn();
    }

    notifyListeners();
  }

  // =====================================================
  // ACCIONES DE CELDA
  // =====================================================

  Future<void> _applyBoardAction(Player player) async {
    if (player.position == 0) return;

    final Cell cell = engine.board.cells[player.position];
    final BoardAction? action = cell.action;

    if (action == null) return;

    switch (action.type) {
      case BoardActionType.goToStart:
        player.resetToStart();
        break;

      case BoardActionType.moveTo:
        if (action.targetNumber != null) {
          await Future.delayed(const Duration(milliseconds: 300));
          player.position = action.targetNumber!;
        }
        break;

      case BoardActionType.skipTurn:
        player.skippedTurns++;
        break;

      case BoardActionType.rollAgain:
        break;
    }
  }

  // =====================================================
  // COLISIONES
  // =====================================================

  void _checkCollisions(Player current) {
    for (final other in players) {
      if (other == current) continue;

      if (other.position == current.position) {
        other.resetToStart();
      }
    }
  }
}
