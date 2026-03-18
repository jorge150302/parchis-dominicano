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
  final bool vsAI; // ✅ Modo IA local

  LocalGameController({required super.engine, this.vsAI = false});

  @override
  void startTurn() {
    if (currentPlayer.mustSkipTurn) {
      currentPlayer.consumeSkip();
      engine.nextTurn();
      notifyListeners();
      Future.microtask(startTurn);
    } else {
      notifyListeners();
      // ✅ REGLA 1: Si es modo IA y no es el Jugador 1 (index 0), la IA tira sola
      if (vsAI && currentPlayer.index != 0 && engine.phase != GamePhase.finished) {
        Future.delayed(const Duration(milliseconds: 1500), () => rollDice());
      }
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
      // Tirar de nuevo - En modo IA, llamamos a startTurn para que decida si tira solo
      startTurn();
      _unlockInputLater();
      return;
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
        final String targetId = data['playerId'] ?? currentPlayer.id;
        final bool isMe = targetId == PrefsService.playerId;
        _lastServerDiceValue = data['diceValue'];

        if (isMe) {
          diceValue = data['diceValue'];
          notifyListeners();
        } else {
          if (!rollingDice || rollingPlayerId != targetId) {
            _animateRemoteDice(data['diceValue'], targetId);
          }
        }
        break;
      case 'chat': _handleChatMessage(data); break;
      case 'game_event':
        engine.events.add(GameEvent(message: data['message'] ?? ''));
        notifyListeners();
        break;
      case 'error':
        engine.events.add(GameEvent(message: data['message'] ?? 'Acción no permitida'));
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
    chatMessages.add(ChatMessage(
      senderId: data['senderId'] ?? '',
      sender: data['sender'] ?? 'Servidor',
      message: data['message'] ?? '',
      timestamp: DateTime.now()
    ));
    notifyListeners();
  }

  @override
  void sendChatMessage(String message) => socketService.send('chat_message', {'message': message});

  void _updateGameState(Map<String, dynamic> data) {
    final List serverPlayers = data['players'] ?? [];
    final String? currentPlayerId = data['currentPlayerId'];
    final String? phaseStr = data['phase'];
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

      player.skippedTurns = playerData['skippedTurns'] ?? 0;
      player.extraTurns = playerData['extraTurns'] ?? 0;
      player.consecutiveSixes = playerData['consecutiveSixes'] ?? 0;

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

    if (phaseStr == 'finished') {
      engine.phase = GamePhase.finished;
      engine.finishedPlayers.clear();
      for (var winnerId in winners) {
        final winner = engine.players.firstWhere((p) => p.id == winnerId);
        engine.finishedPlayers.add(winner);
      }
      if (PrefsService.lastRoomCode == currentRoomCode) {
        PrefsService.lastRoomCode = null;
      }
    } else if (phaseStr == 'moving') {
      engine.phase = GamePhase.moving;
      inputLocked = true;
    } else if (phaseStr == 'rolling') {
      engine.phase = GamePhase.rolling;
    } else {
      engine.phase = GamePhase.idle;
    }

    if (currentPlayerId != null) engine.setCurrentPlayerById(currentPlayerId);

    if (_animatingPlayers.isEmpty && engine.phase != GamePhase.moving) {
      inputLocked = false;
    }
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
    if (engine.phase != GamePhase.moving) inputLocked = false;
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
  final String senderId;
  final String sender;
  final String message;
  final DateTime timestamp;
  ChatMessage({required this.senderId, required this.sender, required this.message, required this.timestamp});
}
