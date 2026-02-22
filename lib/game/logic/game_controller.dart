import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_event.dart';
import '../models/player.dart';
import 'game_engine.dart';

class GameController extends ChangeNotifier {
  final GameEngine engine;

  GameController(this.engine);

  bool rollingDice = false;
  bool _inputLocked = false;

  int diceValue = 1;

  final AudioPlayer _diceAudio = AudioPlayer();
  final AudioPlayer _fanfareAudio = AudioPlayer();
  final AudioPlayer _sendToHomeAudio = AudioPlayer();
  final Random _random = Random();

  static const _diceAnimDuration = Duration(milliseconds: 300);
  static const _inputLockDuration = Duration(milliseconds: 1500);

  List<Player> get players => engine.players;
  Player get currentPlayer => engine.currentPlayer;

  List<GameEvent> consumeEvents() {
    final events = List<GameEvent>.from(engine.events);
    engine.clearEvents();
    return events;
  }

  @override
  void dispose() {
    _diceAudio.dispose();
    _fanfareAudio.dispose();
    _sendToHomeAudio.dispose();
    super.dispose();
  }

  void setPlayers(List<Player> newPlayers) {
    engine.players
      ..clear()
      ..addAll(newPlayers);
    notifyListeners();
  }

  Future<void> playFanfare() async {
    if (_fanfareAudio.state == PlayerState.playing) return;
    await _fanfareAudio.play(AssetSource('sounds/fanfarreas.mp3'));
    final completer = Completer();
    _fanfareAudio.onPlayerComplete.first.then((_) => completer.complete());
    return completer.future;
  }

  Future<void> playSendToHomeSound() async {
    if (_sendToHomeAudio.state == PlayerState.playing) {
      return;
    }
    await _sendToHomeAudio.play(AssetSource('sounds/send_to_home.mp3'));
    final completer = Completer();
    _sendToHomeAudio.onPlayerComplete.first.then((_) => completer.complete());
    return completer.future;
  }

  void startTurn() {
    if (currentPlayer.mustSkipTurn) {
      currentPlayer.consumeSkip();
      engine.nextTurn();
      notifyListeners();
      // Vuelve a comprobar si el nuevo jugador también debe saltarse el turno
      Future.microtask(startTurn);
    } else {
      // El jugador actual puede jugar
      notifyListeners();
    }
  }

  Future<void> rollDice() async {
    if (rollingDice || engine.phase == GamePhase.finished || _inputLocked || currentPlayer.mustSkipTurn) return;

    _inputLocked = true;

    final player = currentPlayer;

    rollingDice = true;
    notifyListeners();

    if (_diceAudio.state == PlayerState.playing) {
      await _diceAudio.stop();
    }
    _diceAudio.play(AssetSource('sounds/dice.mp3'));
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
      if (engine.penaltyThreeSixes(player)) {
        await playSendToHomeSound();
      }
      player.extraTurns = 0;
      engine.nextTurn(); // Finaliza el turno después de la penalización
      startTurn(); // Inicia el turno para el siguiente jugador
      _unlockInputLater();
      return;
    }

    final bool canMove = engine.canMove(player, diceValue);

    if (canMove) {
      await _moveStepByStep(diceValue);
    }

    // --- Lógica de fin de turno ---
    if (player.isFinished) {
      engine.nextTurn();
    } else if (player.extraTurns > 0) {
      player.extraTurns--;
    } else {
      engine.nextTurn();
    }

    startTurn(); // Inicia el turno para el siguiente jugador

    _unlockInputLater();
  }

  void _unlockInputLater() {
    Future.delayed(_inputLockDuration, () {
      _inputLocked = false;
      notifyListeners();
    });
  }

  Future<void> _moveStepByStep(int steps) async {
    final player = currentPlayer;

    engine.phase = GamePhase.moving;

    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 240));
      engine.stepForward(player);
      notifyListeners();
      if (player.isFinished) {
        await playFanfare();
      }
      if (engine.phase == GamePhase.finished) return;
    }

    engine.stopMoving(player);

    final sentHomeByAction = engine.applyCellAction(player);
    final sentHomeByCollision = engine.resolveCollisions(player);

    if (sentHomeByAction || sentHomeByCollision) {
      await playSendToHomeSound();
    }

    engine.phase = GamePhase.idle;
    notifyListeners();
  }
}
