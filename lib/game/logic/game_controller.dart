import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/service/prefs_service.dart';

import '../models/game_event.dart';
import '../models/player.dart';
import 'game_engine.dart';

abstract class GameController extends ChangeNotifier {
  final GameEngine engine;
  
  bool rollingDice = false;
  String? rollingPlayerId;
  bool inputLocked = false;
  int diceValue = 1;

  final AudioPlayer diceAudio = AudioPlayer();
  final AudioPlayer fanfareAudio = AudioPlayer();
  final AudioPlayer sendToHomeAudio = AudioPlayer();
  final Random random = Random();

  static const diceAnimDuration = Duration(milliseconds: 300);
  static const inputLockDuration = Duration(milliseconds: 1000);

  List<ChatMessage> chatMessages = [];

  GameController({required this.engine});

  List<Player> get players => engine.players;
  Player get currentPlayer => engine.currentPlayer;
  
  bool get isOnline => false;

  bool get isMyTurn {
    if (!isOnline) return true;
    return currentPlayer.id == PrefsService.playerId;
  }

  List<GameEvent> consumeEvents() {
    final events = List<GameEvent>.from(engine.events);
    engine.clearEvents();
    return events;
  }

  void setPlayers(List<Player> newPlayers) {
    engine.players..clear()..addAll(newPlayers);
    notifyListeners();
  }

  Future<void> playFanfare() async {
    if (fanfareAudio.state == PlayerState.playing) return;
    await fanfareAudio.play(AssetSource('sounds/fanfarreas.mp3'));
    final completer = Completer();
    fanfareAudio.onPlayerComplete.first.then((_) => completer.complete());
    return completer.future;
  }

  Future<void> playSendToHomeSound() async {
    if (sendToHomeAudio.state == PlayerState.playing) return;
    await sendToHomeAudio.play(AssetSource('sounds/send_to_home.mp3'));
    final completer = Completer();
    sendToHomeAudio.onPlayerComplete.first.then((_) => completer.complete());
    return completer.future;
  }

  void startTurn();
  Future<void> rollDice();
  void sendChatMessage(String message);

  @override
  void dispose() {
    diceAudio.dispose();
    fanfareAudio.dispose();
    sendToHomeAudio.dispose();
    super.dispose();
  }
}

class LocalGameController extends GameController {
  LocalGameController({required super.engine});

  @override
  void startTurn() {
    if (currentPlayer.mustSkipTurn) {
      currentPlayer.consumeSkip();
      engine.nextTurn();
      notifyListeners();
      Future.microtask(startTurn);
    } else {
      notifyListeners();
    }
  }

  @override
  void sendChatMessage(String message) {}

  @override
  Future<void> rollDice() async {
    if (rollingDice || engine.phase == GamePhase.finished || inputLocked || currentPlayer.mustSkipTurn) return;

    inputLocked = true;
    rollingDice = true;
    rollingPlayerId = currentPlayer.id;
    notifyListeners();

    diceAudio.play(AssetSource('sounds/dice.mp3'));
    HapticFeedback.lightImpact();

    for (int i = 0; i < 14; i++) {
      diceValue = random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    diceValue = engine.rollDice();
    notifyListeners();

    await Future.delayed(GameController.diceAnimDuration);
    rollingDice = false;
    rollingPlayerId = null;
    notifyListeners();

    final player = currentPlayer;
    if (diceValue == 6) player.consecutiveSixes++;
    else player.consecutiveSixes = 0;

    if (engine.reachedThreeSixes(player)) {
      if (engine.penaltyThreeSixes(player)) await playSendToHomeSound();
      engine.nextTurn();
      startTurn();
      _unlockInputLater();
      return;
    }

    if (engine.canMove(player, diceValue)) {
      await _moveStepByStep(diceValue);
    }

    if (player.isFinished) {
      engine.nextTurn();
    } else if (diceValue == 6) {
      // Se queda igual
    } else {
      engine.nextTurn();
    }

    startTurn();
    _unlockInputLater();
  }

  void _unlockInputLater() {
    Future.delayed(GameController.inputLockDuration, () {
      inputLocked = false;
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
      if (player.isFinished) await playFanfare();
      if (engine.phase == GamePhase.finished) return;
    }

    engine.stopMoving(player);
    final sentHomeByAction = engine.applyCellAction(player);
    final sentHomeByCollision = engine.resolveCollisions(player);

    if (sentHomeByAction || sentHomeByCollision) await playSendToHomeSound();

    engine.phase = GamePhase.idle;
    notifyListeners();
  }
}

class NetworkGameController extends GameController {
  final SocketService socketService;
  StreamSubscription? _socketSubscription;
  String? currentRoomCode;
  final Set<String> _animatingPlayers = {};
  int _lastServerDiceValue = 0;

  @override
  bool get isOnline => true;

  NetworkGameController({required super.engine, required this.socketService}) {
    _socketSubscription = socketService.events.listen(_handleServerEvent);
    if (socketService.lastGameState != null) {
      Future.microtask(() => _updateGameState(socketService.lastGameState!));
    }
  }

  @override
  void startTurn() => notifyListeners();

  void _handleServerEvent(Map<String, dynamic> event) {
    final eventName = event['event'];
    final data = event['data'];
    switch (eventName) {
      case 'game_state': _updateGameState(data); break;
      case 'dice_result': 
        _lastServerDiceValue = data['diceValue'];
        if (!rollingDice) {
          _animateRemoteDice(data['diceValue'], data['playerId'] ?? currentPlayer.id);
        } else {
          diceValue = data['diceValue'];
          notifyListeners();
        }
        break;
      case 'chat': _handleChatMessage(data); break;
      case 'game_event':
        engine.events.add(GameEvent(message: data['message'] ?? ''));
        notifyListeners();
        break;
    }
  }

  Future<void> _animateRemoteDice(int finalValue, String targetPlayerId) async {
    rollingDice = true;
    rollingPlayerId = targetPlayerId;
    notifyListeners();

    diceAudio.play(AssetSource('sounds/dice.mp3'));
    for (int i = 0; i < 8; i++) {
      diceValue = random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 70));
    }
    diceValue = finalValue;
    await Future.delayed(GameController.diceAnimDuration);
    
    rollingDice = false;
    rollingPlayerId = null;
    notifyListeners();
  }

  void _handleChatMessage(Map<String, dynamic> data) {
    chatMessages.add(ChatMessage(sender: data['sender'] ?? 'Servidor', message: data['message'] ?? '', timestamp: DateTime.now()));
    notifyListeners();
  }

  @override
  void sendChatMessage(String message) => socketService.send('chat_message', {'message': message});

  void _updateGameState(Map<String, dynamic> data) {
    final List serverPlayers = data['players'] ?? [];
    final String? currentPlayerId = data['currentPlayerId'];
    final String? phase = data['phase'];
    final List winners = data['winners'] ?? [];
    currentRoomCode = data['roomCode'] ?? currentRoomCode;

    final tokens = ['assets/tokens/red.png', 'assets/tokens/blue.png', 'assets/tokens/green.png', 'assets/tokens/yellow.png'];

    for (var playerData in serverPlayers) {
      final String id = playerData['id'];
      final int targetPosition = playerData['position'] ?? 0;
      final int slotIndex = playerData['index'] ?? 0;
      
      final player = engine.players.firstWhere(
        (p) => p.id == id,
        orElse: () {
          final p = Player(id: id, name: playerData['name'], index: slotIndex, tokenAsset: tokens[slotIndex % tokens.length]);
          engine.players.add(p);
          return p;
        },
      );

      if (player.position != targetPosition && !_animatingPlayers.contains(id)) {
        int jump = (targetPosition - player.position).abs();
        if (jump != _lastServerDiceValue) {
          player.position = targetPosition;
          if (targetPosition < player.position) playSendToHomeSound();
          notifyListeners();
        } else {
          _animatePlayerMovement(player, targetPosition);
        }
      }

      player.isFinished = playerData['isFinished'] ?? false;
      player.isAI = playerData['isAI'] ?? false;
    }

    // ✅ SINCRONIZACIÓN DE FIN DE JUEGO
    if (phase == 'finished') {
      engine.phase = GamePhase.finished;
      // Sincronizamos la lista de ganadores en orden
      engine.finishedPlayers.clear();
      for (var winnerId in winners) {
        final winner = engine.players.firstWhere((p) => p.id == winnerId);
        engine.finishedPlayers.add(winner);
      }
    } else {
      engine.phase = GamePhase.idle;
    }

    if (currentPlayerId != null) engine.setCurrentPlayerById(currentPlayerId);
    if (_animatingPlayers.isEmpty) inputLocked = false;
    notifyListeners();
  }

  Future<void> _animatePlayerMovement(Player player, int target) async {
    _animatingPlayers.add(player.id);
    inputLocked = true;

    if (target < player.position) {
      player.position = target;
      await playSendToHomeSound();
      notifyListeners();
    } else {
      while (player.position < target) {
        await Future.delayed(const Duration(milliseconds: 250));
        player.moveBy(1);
        notifyListeners();
        if (player.isFinished) await playFanfare();
      }
    }
    _animatingPlayers.remove(player.id);
    inputLocked = false;
    notifyListeners();
  }

  @override
  Future<void> rollDice() async {
    if (!isMyTurn || engine.currentPlayer.isAI || rollingDice || inputLocked || engine.phase == GamePhase.finished) return;
    inputLocked = true;
    rollingDice = true;
    rollingPlayerId = PrefsService.playerId;
    notifyListeners();
    HapticFeedback.lightImpact();
    diceAudio.play(AssetSource('sounds/dice.mp3'));
    for (int i = 0; i < 10; i++) {
      diceValue = random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 60));
    }
    socketService.send('roll_dice');
    await Future.delayed(GameController.diceAnimDuration);
    rollingDice = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}

class ChatMessage {
  final String sender;
  final String message;
  final DateTime timestamp;
  ChatMessage({required this.sender, required this.message, required this.timestamp});
}
