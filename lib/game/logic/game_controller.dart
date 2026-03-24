import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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
  List<int> movableTokenIds = []; 

  double turnProgress = 1.0;
  int secondsRemaining = 20;

  final AudioPlayer diceAudio = AudioPlayer();
  final AudioPlayer fanfareAudio = AudioPlayer();
  final AudioPlayer sendToHomeAudio = AudioPlayer();
  final Random random = Random();

  List<ChatMessage> chatMessages = [];
  
  // ✅ Lista de jugadores bloqueados (por ID)
  final Set<String> blockedPlayerIds = {};

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

  // ✅ Métodos de Moderación
  void toggleBlockPlayer(String playerId) {
    if (blockedPlayerIds.contains(playerId)) {
      blockedPlayerIds.remove(playerId);
    } else {
      blockedPlayerIds.add(playerId);
    }
    notifyListeners();
  }

  void reportPlayer(String reportedId, String reason) {
    // Implementado en NetworkGameController
  }

  Future<void> playFanfare() async {
    await fanfareAudio.play(AssetSource('sounds/fanfarreas.mp3'));
  }

  Future<void> playSendToHomeSound() async {
    await sendToHomeAudio.play(AssetSource('sounds/send_to_home.mp3'));
  }

  void startTurn();
  Future<void> rollDice();
  void selectToken(int tokenId); 
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
  final bool vsAI;

  LocalGameController({required super.engine, this.vsAI = false});

  @override
  void startTurn() {
    if (engine.phase == GamePhase.finished) {
      notifyListeners();
      return;
    }

    engine.phase = GamePhase.idle;
    movableTokenIds.clear();
    inputLocked = false;
    notifyListeners();
    
    if (vsAI && currentPlayer.index != 0 && engine.phase != GamePhase.finished) {
      Future.delayed(const Duration(milliseconds: 1500), () => rollDice());
    }
  }

  @override
  void selectToken(int tokenId) async {
    if (engine.phase != GamePhase.choosing_token || !movableTokenIds.contains(tokenId) || inputLocked) return;
    
    inputLocked = true;
    movableTokenIds.clear();
    await _moveStepByStep(tokenId, diceValue);
    
    if (engine.phase == GamePhase.idle) {
      startTurn();
    } else if (engine.phase != GamePhase.finished) {
      engine.nextTurn();
      startTurn();
    } else {
      notifyListeners();
    }
  }

  @override
  Future<void> rollDice() async {
    if (rollingDice || engine.phase != GamePhase.idle || inputLocked) return;

    inputLocked = true;
    rollingDice = true;
    rollingPlayerId = currentPlayer.id;
    notifyListeners();

    diceAudio.play(AssetSource('sounds/dice.mp3'));
    for (int i = 0; i < 12; i++) {
      diceValue = random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    rollingDice = false;
    rollingPlayerId = null;
    
    engine.registerSix(currentPlayer, diceValue);
    
    if (engine.reachedThreeSixes(currentPlayer)) {
      engine.penaltyThreeSixes(currentPlayer);
      await playSendToHomeSound();
      engine.nextTurn();
      startTurn();
      return;
    }

    movableTokenIds = engine.getMovableTokenIds(diceValue);
    
    if (movableTokenIds.isEmpty) {
      engine.events.add(GameEvent(messageKey: 'player_cant_move', args: {'name': currentPlayer.name}));
      notifyListeners();
      await Future.delayed(const Duration(seconds: 1));
      
      if (diceValue == 6) {
        startTurn();
      } else {
        engine.nextTurn();
        startTurn();
      }
    } else {
      engine.phase = GamePhase.choosing_token;
      inputLocked = false;
      notifyListeners();
      
      if (vsAI && currentPlayer.index != 0) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          int selectedId = movableTokenIds.first;
          if (diceValue == 5) {
            final homeToken = movableTokenIds.indexWhere((id) => currentPlayer.tokens[id].position == 0);
            if (homeToken != -1) selectedId = movableTokenIds[homeToken];
          } else {
            movableTokenIds.sort((a, b) => currentPlayer.tokens[b].position.compareTo(currentPlayer.tokens[a].position));
            selectedId = movableTokenIds.first;
          }
          selectToken(selectedId);
        });
      }
    }
  }

  Future<void> _moveStepByStep(int tokenId, int steps) async {
    engine.phase = GamePhase.moving;
    for (int i = 0; i < steps; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      engine.stepForward(currentPlayer, tokenId);
      notifyListeners();
      if (currentPlayer.tokens[tokenId].isFinished) {
         await playFanfare();
         break;
      }
    }
    
    final movedByAction = engine.applyCellAction(currentPlayer, tokenId);
    if (movedByAction) {
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
    }

    final hit = engine.resolveCollisions(currentPlayer, tokenId);
    if (hit || movedByAction) await playSendToHomeSound();
    
    notifyListeners();
  }

  @override
  void sendChatMessage(String message) {}
}

class NetworkGameController extends GameController {
  final SocketService socketService;
  StreamSubscription? _socketSubscription;
  final Set<String> _animatingTokens = {}; 
  int _lastServerDiceValue = 1;

  NetworkGameController({required super.engine, required this.socketService}) {
    _socketSubscription = socketService.events.listen(_handleServerEvent);
    if (socketService.lastGameState != null) {
      Future.microtask(() => _updateGameState(socketService.lastGameState!));
    }
  }

  @override
  bool get isOnline => true;

  @override
  void startTurn() => notifyListeners();

  @override
  void selectToken(int tokenId) {
    if (!isMyTurn || engine.phase != GamePhase.choosing_token) return;
    socketService.send('move_token', {'tokenId': tokenId});
    engine.phase = GamePhase.moving;
    movableTokenIds.clear();
    notifyListeners();
  }

  @override
  Future<void> rollDice() async {
    if (!isMyTurn || engine.phase != GamePhase.idle || rollingDice) return;
    
    rollingDice = true;
    rollingPlayerId = PrefsService.playerId;
    notifyListeners();
    
    diceAudio.play(AssetSource('sounds/dice.mp3'));
    socketService.send('roll_dice');
  }

  @override
  void reportPlayer(String reportedId, String reason) {
    socketService.send('report_player', {
      'reportedId': reportedId,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _handleServerEvent(Map<String, dynamic> event) {
    final eventName = event['event'];
    final data = event['data'];
    switch (eventName) {
      case 'game_state': _updateGameState(data); break;
      case 'dice_result': 
        _lastServerDiceValue = data['diceValue'];
        rollingPlayerId = data['playerId'];
        _animateRemoteDice(_lastServerDiceValue, rollingPlayerId!);
        break;
      case 'game_event':
        engine.events.add(GameEvent(messageKey: data['message'] ?? ''));
        notifyListeners();
        break;
      case 'timer_update':
        secondsRemaining = data['seconds'] ?? 20;
        turnProgress = secondsRemaining / 20.0;
        notifyListeners();
        break;
      case 'chat': _handleChatMessage(data); break;
    }
  }

  void _updateGameState(Map<String, dynamic> data) {
    final List serverPlayers = data['players'] ?? [];
    final String? currentPlayerId = data['currentPlayerId'];
    final String? phaseStr = data['phase'];
    final List? winnersIds = data['winners']; 
    
    if (data['lastDiceValue'] != null) {
      _lastServerDiceValue = data['lastDiceValue'];
      if (!rollingDice) diceValue = _lastServerDiceValue;
    }

    if (winnersIds != null) {
      engine.finisherIds.clear();
      engine.finisherIds.addAll(winnersIds.cast<String>());
    }

    if (data['timer'] != null) {
      secondsRemaining = data['timer'];
      turnProgress = secondsRemaining / 20.0;
    }

    final tokensAssets = ['assets/tokens/red.png', 'assets/tokens/blue.png', 'assets/tokens/green.png', 'assets/tokens/yellow.png'];

    for (var playerData in serverPlayers) {
      final String id = playerData['id'];
      final int slotIndex = playerData['index'] ?? 0;
      
      final player = engine.players.firstWhere(
        (p) => p.id == id,
        orElse: () {
          final p = Player(
            id: id, 
            name: playerData['name'], 
            index: slotIndex, 
            tokenAsset: tokensAssets[slotIndex % tokensAssets.length],
            tokenCount: 2 
          );
          engine.players.add(p);
          return p;
        },
      );

      final List? tokensData = playerData['tokens'];
      if (tokensData != null) {
        for (var tData in tokensData) {
          int tId = tData['id'] ?? 0;
          int serverPos = tData['position'] ?? 0;
          bool serverIsFinished = tData['isFinished'] ?? false;
          
          if (tId < player.tokens.length) {
            final token = player.tokens[tId];
            String animKey = "${player.id}_$tId";

            if (token.position != serverPos && !_animatingTokens.contains(animKey)) {
              _animateTokenMovement(player, tId, serverPos);
            } else if (!_animatingTokens.contains(animKey)) {
              token.isFinished = serverIsFinished;
            }
          }
        }
      }
      player.isAI = playerData['isAI'] ?? player.isAI;
    }

    if (phaseStr == 'choosing_token') {
      engine.phase = GamePhase.choosing_token;
      if (currentPlayerId == PrefsService.playerId) {
        movableTokenIds = engine.getMovableTokenIds(_lastServerDiceValue);
      }
    } else if (phaseStr == 'rolling') {
      engine.phase = GamePhase.idle;
      movableTokenIds.clear();
      rollingDice = false;
    } else if (phaseStr == 'moving') {
      engine.phase = GamePhase.moving;
    } else if (phaseStr == 'finished') {
      engine.phase = GamePhase.finished;
    }

    if (currentPlayerId != null) engine.setCurrentPlayerById(currentPlayerId);
    notifyListeners();
  }

  Future<void> _animateTokenMovement(Player player, int tokenId, int targetPos) async {
    String animKey = "${player.id}_$tokenId";
    _animatingTokens.add(animKey);
    
    final token = player.tokens[tokenId];
    
    if (targetPos < token.position || (targetPos - token.position).abs() > 6) {
      await Future.delayed(const Duration(milliseconds: 500));
      token.position = targetPos;
      if (targetPos == 0) await playSendToHomeSound();
    } else {
      while (token.position < targetPos) {
        await Future.delayed(const Duration(milliseconds: 250));
        token.position++;
        if (token.position == engine.board.finalPosition) {
          token.isFinished = true;
          await playFanfare();
          break;
        }
        notifyListeners();
      }
    }
    
    _animatingTokens.remove(animKey);
    notifyListeners();
  }

  Future<void> _animateRemoteDice(int finalVal, String pid) async {
    rollingDice = true;
    rollingPlayerId = pid;
    notifyListeners();
    
    if (pid != PrefsService.playerId) {
      diceAudio.play(AssetSource('sounds/dice.mp3'));
    }

    for (int i = 0; i < 10; i++) {
      diceValue = random.nextInt(6) + 1;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 80));
    }
    
    diceValue = finalVal;
    rollingDice = false;
    notifyListeners();
  }

  void _handleChatMessage(Map<String, dynamic> data) {
    final senderId = data['senderId'] ?? '';
    
    // ✅ Si el jugador está bloqueado, ignoramos su mensaje
    if (blockedPlayerIds.contains(senderId)) return;

    chatMessages.add(ChatMessage(
      senderId: senderId,
      sender: data['sender'] ?? 'Servidor',
      message: data['message'] ?? '',
      timestamp: DateTime.now()
    ));
    notifyListeners();
  }

  @override
  void sendChatMessage(String message) => socketService.send('chat_message', {'message': message});

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
