import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/player.dart';
import 'game_engine.dart';

class GameController extends ChangeNotifier {
  final GameEngine engine;

  GameController(this.engine);

  bool rollingDice = false;
  bool _inputLocked = false;

  int diceValue = 1;

  final AudioPlayer _audio = AudioPlayer();
  final Random _random = Random();

  static const _diceAnimDuration = Duration(milliseconds: 300);
  static const _inputLockDuration = Duration(milliseconds: 1500);

  List<Player> get players => engine.players;
  Player get currentPlayer => engine.currentPlayer;

  void setPlayers(List<Player> newPlayers) {
    engine.players
      ..clear()
      ..addAll(newPlayers);
    notifyListeners();
  }

  Future<void> rollDice() async {
    if (rollingDice || engine.phase == GamePhase.finished || _inputLocked) return;

    _inputLocked = true;

    final player = currentPlayer;

    if (player.mustSkipTurn) {
      player.consumeSkip();
      engine.nextTurn();
      notifyListeners();
      _unlockInputLater();
      return;
    }

    rollingDice = true;
    notifyListeners();

    _audio.play(AssetSource('sounds/dice.mp3'));
    HapticFeedback.lightImpact();

    for (int i = 0; i < 14; i++) {
      diceValue = _random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    diceValue = engine.rollDice();
    notifyListeners();

    await Future.delayed(_diceAnimDuration);

    rollingDice = false;
    notifyListeners();

    // --- Lógica unificada para todos los jugadores ---
    if (diceValue == 6) {
      player.extraTurns++;
    }
    engine.registerSix(player, diceValue);

    if (engine.reachedThreeSixes(player)) {
      engine.penaltyThreeSixes(player);
      player.extraTurns = 0;
      notifyListeners();
      _unlockInputLater();
      return;
    }

    if (!engine.canMove(player, diceValue)) {
      engine.nextTurn();
      notifyListeners();
      _unlockInputLater();
      return;
    }

    await _moveStepByStep(diceValue);

    if (player.extraTurns > 0) {
      player.extraTurns--;
    } else {
      engine.nextTurn();
    }

    notifyListeners();
    _unlockInputLater();
  }

  void _unlockInputLater() {
    Future.delayed(_inputLockDuration, () {
      _inputLocked = false;
    });
  }

  Future<void> _moveStepByStep(int steps) async {
    final player = currentPlayer;

    engine.phase = GamePhase.moving;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 240));
      engine.stepForward(player);
      notifyListeners();
      if (engine.phase == GamePhase.finished) return;
    }

    engine.stopMoving(player);

    engine.applyCellAction(player);
    engine.resolveCollisions(player);

    engine.phase = GamePhase.idle;
    notifyListeners();
  }
}
