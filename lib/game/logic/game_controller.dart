import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../models/player.dart';
import 'game_engine.dart';

class GameController extends ChangeNotifier {
  final GameEngine engine;

  GameController(this.engine);

  // =====================================================
  // STATE
  // =====================================================

  bool rollingDice = false;
  int diceValue = 1;

  final AudioPlayer _audio = AudioPlayer();
  final Random _random = Random();

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
  // 🎲 DICE
  // =====================================================

  Future<void> rollDice() async {
    if (rollingDice || engine.finished) return;

    final player = currentPlayer;

    /// ⏭️ skip
    if (player.mustSkipTurn) {
      player.consumeSkip();
      engine.nextTurn();
      notifyListeners();
      return;
    }

    rollingDice = true;
    notifyListeners();

    _audio.play(AssetSource('sounds/dice.mp3'));
    HapticFeedback.lightImpact();

    /// 🎰 animación fake
    for (int i = 0; i < 14; i++) {
      diceValue = _random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 70));
    }

    /// 🎯 valor real
    diceValue = engine.rollDice();
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 250));

    rollingDice = false;
    notifyListeners();

    // =====================================================
    // 🔥 reglas puras delegadas al engine
    // =====================================================

    engine.registerSix(player, diceValue);

    if (engine.reachedThreeSixes(player)) {
      engine.penaltyThreeSixes(player);
      notifyListeners();
      return;
    }

    if (!engine.canMove(player, diceValue)) {
      engine.nextTurn();
      notifyListeners();
      return;
    }

    await _moveStepByStep(diceValue);
  }

  // =====================================================
  // 🚶 MOVIMIENTO SUAVE (usa engine)
  // =====================================================

  Future<void> _moveStepByStep(int steps) async {
    final player = currentPlayer;

    engine.phase = GamePhase.moving;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 240));

      engine.stepForward(player); // ✅ ya no tocamos position
      notifyListeners();

      if (engine.finished) return;
    }

    engine.stopMoving(player);

    /// acciones de celda
    engine.applyCellAction(player);

    /// colisiones
    engine.resolveCollisions(player);

    /// turno normal
    if (diceValue != 6) {
      engine.nextTurn();
    }

    engine.phase = GamePhase.idle;

    notifyListeners();
  }
}
