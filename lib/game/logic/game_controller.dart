import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/audio_service.dart';

import '../models/game_event.dart';
import '../models/player.dart';
import 'game_engine.dart';
import 'board_generator.dart';
import 'board_presets.dart';
import '../models/board_action.dart';

abstract class GameController extends ChangeNotifier {
  final GameEngine engine;
  
  bool rollingDice = false;
  String? rollingPlayerId;
  bool inputLocked = false;
  int diceValue = 1;
  List<int> movableTokenIds = []; 

  double turnProgress = 1.0;
  int secondsRemaining = 20;
  int maxPlayers = 0; 

  final AudioPlayer diceAudio = AudioPlayer();
  final AudioPlayer fanfareAudio = AudioPlayer();
  final AudioPlayer sendToHomeAudio = AudioPlayer();
  
  final Random random = Random();

  List<ChatMessage> chatMessages = [];
  
  final Set<String> blockedPlayerIds = {};
  
  final Map<String, String> playerQuickMessages = {};
  final Map<String, Timer> _quickMessageTimers = {};

  final StreamController<CapturedToken> _capturedTokenController = StreamController<CapturedToken>.broadcast();
  Stream<CapturedToken> get onTokenCaptured => _capturedTokenController.stream;

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
    if (maxPlayers == 0) maxPlayers = newPlayers.length;
    notifyListeners();
  }

  void toggleBlockPlayer(String playerId) {
    if (blockedPlayerIds.contains(playerId)) {
      blockedPlayerIds.remove(playerId);
    } else {
      blockedPlayerIds.add(playerId);
    }
    notifyListeners();
  }

  void reportPlayer(String reportedId, String reason) {}

  double get _audioPlaybackRate => PrefsService.gameSpeed == GameSpeed.fast ? 1.6 : 1.0;

  Future<void> _playSound(AudioPlayer player, String asset, {bool immediate = false}) async {
    if (PrefsService.soundEnabled) {
      try {
        if (!immediate) await player.stop(); 
        await player.setPlaybackRate(_audioPlaybackRate);
        await player.play(AssetSource(asset));
      } catch (e) {
        debugPrint("Error playing sound $asset: $e");
      }
    }
  }

  Future<void> _vibrate() async {
    if (PrefsService.vibrationEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  /// ✅ Reproduce el sonido de victoria y ESPERA a que termine totalmente
  /// para evitar que el siguiente turno lo corte.
  Future<void> playFanfare() async {
    if (PrefsService.soundEnabled) {
      try {
        await fanfareAudio.stop();
        await fanfareAudio.setPlaybackRate(_audioPlaybackRate);
        await fanfareAudio.play(AssetSource('sounds/fanfarreas.mp3'));
        
        // Esperamos a que termine la reproducción antes de continuar la lógica del juego
        await fanfareAudio.onPlayerComplete.first.timeout(
          const Duration(seconds: 5), 
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint("Error en playFanfare: $e");
      }
    }
  }

  Future<void> playSendToHomeSound() async {
    await _playSound(sendToHomeAudio, 'sounds/send_to_home.mp3');
  }

  Future<void> playMoveSound() async {
    if (PrefsService.soundEnabled) {
      AudioService.playMoveStep();
      if (PrefsService.vibrationEnabled) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void startTurn();
  Future<void> rollDice();
  Future<void> selectToken(int tokenId); 
  void sendChatMessage(String message);
  void sendQuickChat(String message);
  void toggleAutoPlay(bool value);

  void setQuickMessage(String playerId, String message) {
    _quickMessageTimers[playerId]?.cancel();
    playerQuickMessages[playerId] = message;
    notifyListeners();

    _quickMessageTimers[playerId] = Timer(const Duration(seconds: 3), () {
      playerQuickMessages.remove(playerId);
      _quickMessageTimers.remove(playerId);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    diceAudio.dispose();
    fanfareAudio.dispose();
    sendToHomeAudio.dispose();
    _capturedTokenController.close();
    for (var timer in _quickMessageTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

class LocalGameController extends GameController {
  final bool vsAI;
  bool _isTutorial = false;
  int _tutorialDiceIndex = 0;

  LocalGameController({required super.engine, this.vsAI = false, bool isTutorial = false}) {
    _isTutorial = isTutorial;
  }

  bool get _isHumanTurn => !vsAI || currentPlayer.index == 0;

  void _saveGame() {
    if (_isTutorial) return; 
    if (engine.phase == GamePhase.finished) {
      PrefsService.savedLocalGame = null;
    } else {
      final state = engine.toJson();
      state['vsAI'] = vsAI;
      state['diceValue'] = diceValue;
      PrefsService.savedLocalGame = jsonEncode(state);
    }
  }

  Duration get _aiDecisionDelay => PrefsService.gameSpeed == GameSpeed.fast
      ? const Duration(milliseconds: 300)
      : const Duration(milliseconds: 1200);

  Duration get _aiSelectionDelay => PrefsService.gameSpeed == GameSpeed.fast
      ? const Duration(milliseconds: 200)
      : const Duration(milliseconds: 800);

  Duration get _stepDelay => PrefsService.gameSpeed == GameSpeed.fast
      ? const Duration(milliseconds: 100)
      : const Duration(milliseconds: 250);

  Duration get _eventDelay => PrefsService.gameSpeed == GameSpeed.fast
      ? const Duration(milliseconds: 500)
      : const Duration(seconds: 1);

  int get _autoMoveDelayMs {
    int baseDelay = PrefsService.autoMoveDelayMs;
    return PrefsService.gameSpeed == GameSpeed.fast ? (baseDelay ~/ 2) : baseDelay;
  }

  @override
  void toggleAutoPlay(bool value) {
    if (isMyTurn) {
      currentPlayer.isAutoPlaying = value;
      notifyListeners();
      if (value && engine.phase == GamePhase.idle) rollDice();
      else if (value && engine.phase == GamePhase.choosing_token) _checkAutoMove(force: true);
    }
  }

  void initializeFromResume(int savedDiceValue) {
    diceValue = savedDiceValue;
    currentPlayer.lastDiceValue = savedDiceValue;

    if (engine.phase == GamePhase.choosing_token) {
      movableTokenIds = engine.getMovableTokenIds(diceValue);
      inputLocked = false;
      _checkAutoMove();
    } else if (engine.phase == GamePhase.moving) {
      engine.phase = GamePhase.choosing_token;
      movableTokenIds = engine.getMovableTokenIds(diceValue);
      inputLocked = false;
      _checkAutoMove();
    }

    if ((vsAI && currentPlayer.index != 0 || currentPlayer.isAutoPlaying) && engine.phase == GamePhase.idle && !_isTutorial) {
      Future.delayed(_aiDecisionDelay, () => rollDice());
    } else if ((vsAI && currentPlayer.index != 0 || currentPlayer.isAutoPlaying) && engine.phase == GamePhase.choosing_token && !_isTutorial) {
      _triggerAISelection();
    }

    notifyListeners();
  }

  @override
  void startTurn() {
    if (engine.phase == GamePhase.finished) {
      _saveGame();
      notifyListeners();
      return;
    }

    engine.phase = GamePhase.idle;
    movableTokenIds.clear();
    inputLocked = false;
    _saveGame();

    if (_isHumanTurn) {
      _vibrate();
    }

    notifyListeners();
    
    if ((vsAI && currentPlayer.index != 0 || currentPlayer.isAutoPlaying) && engine.phase != GamePhase.finished && !_isTutorial) {
      Future.delayed(_aiDecisionDelay, () => rollDice());
    }
  }

  @override
  Future<void> selectToken(int tokenId) async {
    if (engine.phase != GamePhase.choosing_token || inputLocked) return;
    
    if (!movableTokenIds.contains(tokenId)) {
      engine.events.add(GameEvent(
        messageKey: 'player_cant_move',
        playerId: currentPlayer.id,
        type: 'penalty',
        args: {'name': currentPlayer.name}
      ));
      notifyListeners();
      return;
    }

    inputLocked = true;
    movableTokenIds.clear();
    await _moveStepByStep(tokenId, diceValue);
    
    if (engine.phase == GamePhase.idle) {
      startTurn();
    } else if (engine.phase != GamePhase.finished) {
      engine.nextTurn();
      startTurn();
    } else {
      _saveGame();
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

    _playSound(diceAudio, 'sounds/dice.mp3');

    for (int i = 0; i < 12; i++) {
      if (_isTutorial && i == 11) {
        if (_tutorialDiceIndex == 0) diceValue = 5;
        else if (_tutorialDiceIndex == 1) diceValue = 5;
        else if (_tutorialDiceIndex == 2) diceValue = 6;
        else if (_tutorialDiceIndex == 3) diceValue = 1;
        else diceValue = random.nextInt(6) + 1;
      } else {
        diceValue = random.nextInt(6) + 1;
      }
      currentPlayer.lastDiceValue = diceValue; 
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 60));
    }

    if (PrefsService.gameSpeed == GameSpeed.normal) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (_isTutorial) _tutorialDiceIndex++;

    rollingDice = false;
    rollingPlayerId = null;
    currentPlayer.lastDiceValue = diceValue;

    if (diceValue == 6 && _isHumanTurn) _vibrate();

    engine.registerSix(currentPlayer, diceValue);
    
    if (engine.reachedThreeSixes(currentPlayer)) {
      final cap = engine.penaltyThreeSixes(currentPlayer);
      if (cap != null) _capturedTokenController.add(cap);
      await playSendToHomeSound();
      if (_isHumanTurn) _vibrate();
      engine.nextTurn();
      startTurn();
      return;
    }

    movableTokenIds = engine.getMovableTokenIds(diceValue);
    
    if (movableTokenIds.isEmpty) {
      engine.events.add(GameEvent(
        messageKey: 'player_cant_move', 
        playerId: currentPlayer.id,
        type: 'penalty',
        args: {'name': currentPlayer.name}
      ));
      notifyListeners();
      await Future.delayed(_eventDelay);
      
      if (diceValue == 6) {
        startTurn();
      } else {
        engine.nextTurn();
        startTurn();
      }
    } else {
      engine.phase = GamePhase.choosing_token;
      inputLocked = false;
      _saveGame();
      notifyListeners();
      
      if (vsAI && currentPlayer.index != 0 || currentPlayer.isAutoPlaying) {
        if (!_isTutorial) {
          _triggerAISelection();
        }
      } else {
        _checkAutoMove();
      }
    }
  }

  void _checkAutoMove({bool force = false}) {
    if (force || (PrefsService.autoMoveEnabled && movableTokenIds.length == 1)) {
      Future.delayed(Duration(milliseconds: _autoMoveDelayMs), () {
        if (engine.phase == GamePhase.choosing_token && (force || movableTokenIds.length == 1) && !inputLocked) {
          if (force) _triggerAISelection();
          else selectToken(movableTokenIds.first);
        }
      });
    }
  }

  void _triggerAISelection() {
    Future.delayed(_aiSelectionDelay, () {
      if (movableTokenIds.isEmpty) return;

      int selectedId = movableTokenIds.first;
      int maxPriority = -200;

      for (int tokenId in movableTokenIds) {
        int priority = 0;
        final token = currentPlayer.tokens[tokenId];
        final targetPos = token.position + diceValue;

        if (targetPos >= engine.board.finalPosition) {
          priority = 100;
        }
        else if (targetPos > 0) {
          bool canCapture = false;
          for (var other in engine.players) {
            if (other.id == currentPlayer.id) continue;
            for (var otherToken in other.tokens) {
              if (!otherToken.isFinished && otherToken.position == targetPos) {
                canCapture = true;
                break;
              }
            }
            if (canCapture) break;
          }
          if (canCapture) priority = 90;

          final cell = engine.board.getCell(targetPos);
          if (cell.action != null) {
             final actionType = cell.action!.type;
             if (actionType == BoardActionType.goToStart) priority -= 150; 
             else if (actionType == BoardActionType.skipTurn) priority -= 140;
             else if (actionType == BoardActionType.moveTo && cell.action!.targetNumber! < targetPos) priority -= 130;
             else if (actionType == BoardActionType.rollAgain) priority += 20;
          }
        }

        if (priority == 0) {
          priority = 10 + token.position;
        }

        if (priority > maxPriority) {
          maxPriority = priority;
          selectedId = tokenId;
        }
      }

      selectToken(selectedId);
    });
  }

  Future<void> _moveStepByStep(int tokenId, int steps) async {
    engine.phase = GamePhase.moving;
    for (int i = 0; i < steps; i++) {
      playMoveSound(); 
      engine.stepForward(currentPlayer, tokenId);
      notifyListeners();
      
      if (currentPlayer.tokens[tokenId].isFinished) {
         await playFanfare();
         if (_isHumanTurn) _vibrate();
         break;
      }
      
      await Future.delayed(_stepDelay); 
    }
    
    // ✅ Verificamos si cayó en una casilla de acción para sonar el CLIC de botón
    // Se excluye 'goToStart' porque tiene su propio sonido de "send to home"
    final currentPos = currentPlayer.tokens[tokenId].position;
    if (currentPos > 0) {
      final cell = engine.board.getCell(currentPos);
      if (cell.action != null && cell.action!.type != BoardActionType.goToStart) {
        AudioService.playClick();
      }
    }

    final actionRes = engine.applyCellAction(currentPlayer, tokenId);
    if (actionRes.moved) {
       if (actionRes.sentToStart && actionRes.fromPos != null) {
          _capturedTokenController.add(CapturedToken(
            playerIndex: currentPlayer.index,
            asset: currentPlayer.tokenAsset,
            fromPosition: actionRes.fromPos!
          ));
       }
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
    }

    final captured = engine.resolveCollisions(currentPlayer, tokenId);
    if (captured.isNotEmpty) {
      for (var cap in captured) {
        _capturedTokenController.add(cap);
      }
      await playSendToHomeSound();
      if (_isHumanTurn) _vibrate();
      await Future.delayed(Duration(milliseconds: (600 / _audioPlaybackRate).round()));
    } else if (actionRes.moved) {
       if (actionRes.sentToStart) {
         await playSendToHomeSound();
         if (_isHumanTurn) _vibrate();
       }
    }
    
    _saveGame();
    notifyListeners();
  }

  @override
  void sendChatMessage(String message) {}
  
  @override
  void sendQuickChat(String message) {
    setQuickMessage(currentPlayer.id, message);
  }
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
  void toggleAutoPlay(bool value) {
    final me = engine.players.firstWhere((p) => p.id == PrefsService.playerId, orElse: () => currentPlayer);
    me.isAutoPlaying = value;
    notifyListeners();
    socketService.send('toggle_auto_play', {'value': value});
    
    if (value && isMyTurn) {
      if (engine.phase == GamePhase.idle) {
        Future.delayed(const Duration(seconds: 6), () => rollDice());
      } else if (engine.phase == GamePhase.choosing_token) {
        _checkAutoMove(forcedByAFK: true);
      }
    }
  }

  @override
  Future<void> selectToken(int tokenId) async {
    if (!isMyTurn || engine.phase != GamePhase.choosing_token) return;
    
    if (!movableTokenIds.contains(tokenId)) {
      _addCantMoveEvent();
      return;
    }
    
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
    
    _playSound(diceAudio, 'sounds/dice.mp3');
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
        final String msgKey = data['message'] ?? '';
        engine.events.add(GameEvent(
          messageKey: msgKey,
          playerId: data['playerId'] ?? engine.currentPlayer.id,
          type: data['type'] ?? (msgKey == 'player_cant_move' ? 'penalty' : null),
          args: data['args'] != null ? Map<String, String>.from(data['args']) : (msgKey == 'player_cant_move' ? {'name': engine.currentPlayer.name} : null),
        ));
        notifyListeners();
        break;
      case 'timer_update':
        secondsRemaining = data['seconds'] ?? 20;
        turnProgress = secondsRemaining / 20.0;
        
        if (secondsRemaining == 0 && isMyTurn && !currentPlayer.isAutoPlaying) {
          toggleAutoPlay(true);
        }
        
        notifyListeners();
        break;
      case 'chat': _handleChatMessage(data); break;
      case 'quick_chat': 
        final String pid = data['senderId'] ?? '';
        final String msg = data['message'] ?? '';
        if (pid.isNotEmpty && msg.isNotEmpty && !blockedPlayerIds.contains(pid)) {
          setQuickMessage(pid, msg);
        }
        break;
    }
  }

  void _updateGameState(Map<String, dynamic> data) {
    final List serverPlayers = data['players'] ?? [];
    final String? currentPlayerId = data['currentPlayerId'];
    final String? phaseStr = data['phase'];
    final List? winnersIds = data['winners']; 
    final int? serverBoardSize = data['boardSize']; 
    
    if (serverBoardSize != null && serverBoardSize != engine.board.cells.length) {
      final newBoard = generateBoard(classicActionPositions, classicActions, totalCells: serverBoardSize);
      engine.board.cells.clear();
      engine.board.cells.addAll(newBoard.cells);
    }

    if (data['maxPlayers'] != null) {
      maxPlayers = data['maxPlayers'];
    }

    if (data['lastDiceValue'] != null) {
      _lastServerDiceValue = data['lastDiceValue'];
      if (!rollingDice) {
        diceValue = _lastServerDiceValue;
      }
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

      player.lastDiceValue = playerData['lastDiceValue'] ?? player.lastDiceValue;
      player.isAutoPlaying = playerData['isAutoPlaying'] ?? player.isAutoPlaying;

      final List? tokensData = playerData['tokens'];
      if (tokensData != null) {
        for (var tData in tokensData) {
          int tId = tData['id'] ?? 0;
          int serverPos = tData['position'] ?? 0;
          bool serverIsFinished = tData['isFinished'] ?? false;
          
          if (tId < player.tokens.length) {
            final token = player.tokens[tId];
            String animKey = "${player.id}_$tId";
            bool wasFinished = token.isFinished;

            if (token.isFinished) {
              token.position = -1; 
              continue; 
            }

            if (serverIsFinished || serverPos >= engine.board.finalPosition || serverPos == -1) {
              if (!wasFinished && token.position != -1 && !_animatingTokens.contains(animKey)) {
                 _animateTokenMovement(player, tId, engine.board.finalPosition);
              } else {
                token.position = -1;
                token.isFinished = true;
                if (!wasFinished) {
                  playFanfare();
                  _vibrate();
                  engine.events.add(GameEvent(
                    messageKey: 'token_finished_bonus',
                    args: {'name': player.name},
                    playerId: player.id,
                    type: 'bonus'
                  ));
                }
              }
            } else if (token.position != serverPos && !_animatingTokens.contains(animKey)) {
              _animateTokenMovement(player, tId, serverPos);
            } else if (!_animatingTokens.contains(animKey)) {
              token.isFinished = serverIsFinished;
            }
          }
        }
      }
      player.isAI = playerData['isAI'] ?? player.isAI;
    }

    final String? previousPlayerId = engine.currentPlayer.id;
    if (currentPlayerId != null) {
      engine.setCurrentPlayerById(currentPlayerId);
      if (currentPlayerId == PrefsService.playerId && previousPlayerId != currentPlayerId) {
        _vibrate();
      }

      if (!rollingDice) {
        engine.currentPlayer.lastDiceValue = _lastServerDiceValue;
        diceValue = _lastServerDiceValue;
      }
    }

    if (phaseStr == 'choosing_token') {
      engine.phase = GamePhase.choosing_token;
      if (currentPlayerId == PrefsService.playerId) {
        movableTokenIds = engine.getMovableTokenIds(_lastServerDiceValue);

        if (movableTokenIds.isEmpty && !rollingDice) {
          _addCantMoveEvent(engine.currentPlayer);
          
          Future.delayed(const Duration(seconds: 2), () {
            if (engine.phase == GamePhase.choosing_token && movableTokenIds.isEmpty && isMyTurn) {
              socketService.send('skip_turn');
            }
          });
        }

        if (!rollingDice) {
          _checkAutoMove(forcedByAFK: engine.currentPlayer.isAutoPlaying);
        }
      }
    } else if (phaseStr == 'rolling') {
      engine.phase = GamePhase.idle;
      movableTokenIds.clear();
      if (rollingPlayerId == null) {
        rollingDice = false;
      }
    } else if (phaseStr == 'moving') {
      engine.phase = GamePhase.moving;
    } else if (phaseStr == 'finished') {
      engine.phase = GamePhase.finished;
      PrefsService.lastRoomCode = null;
    }

    if (currentPlayerId != null && currentPlayerId == PrefsService.playerId && engine.currentPlayer.isAutoPlaying && engine.phase == GamePhase.idle) {
      Future.delayed(const Duration(seconds: 6), () {
        if (engine.currentPlayer.isAutoPlaying && engine.phase == GamePhase.idle && isMyTurn) {
          rollDice();
        }
      });
    }

    notifyListeners();
  }

  void _addCantMoveEvent([Player? player]) {
    final p = player ?? engine.currentPlayer;
    if (engine.events.any((e) => e.messageKey == 'player_cant_move' && e.playerId == p.id)) return;
    
    engine.events.add(GameEvent(
      messageKey: 'player_cant_move',
      playerId: p.id,
      type: 'penalty',
      args: {'name': p.name}
    ));
    notifyListeners();
  }

  void _checkAutoMove({bool forcedByAFK = false}) {
    if ((forcedByAFK || (PrefsService.autoMoveEnabled && movableTokenIds.length == 1)) && isMyTurn) {
      int delayMs = forcedByAFK ? 6000 : PrefsService.autoMoveDelayMs;
      
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (engine.phase == GamePhase.choosing_token && (forcedByAFK || movableTokenIds.length == 1) && isMyTurn) {
          if (movableTokenIds.isNotEmpty) {
            selectToken(movableTokenIds.first);
          }
        }
      });
    }
  }

  Future<void> _animateTokenMovement(Player player, int tokenId, int targetPos) async {
    String animKey = "${player.id}_$tokenId";
    _animatingTokens.add(animKey);
    
    final token = player.tokens[tokenId];
    
    if (token.isFinished) {
      _animatingTokens.remove(animKey);
      return;
    }

    if (targetPos > token.position) {
      while (token.position < targetPos) {
        playMoveSound(); 
        token.position++;
        notifyListeners();
        
        if (token.position >= engine.board.finalPosition) {
          token.position = -1; 
          token.isFinished = true;
          notifyListeners();
          
          engine.events.add(GameEvent(
            messageKey: 'token_finished_bonus',
            args: {'name': player.name},
            playerId: player.id,
            type: 'bonus'
          ));
          
          await playFanfare(); // ✅ Bloquea hasta el fin del audio
          _vibrate();
          break;
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }
      
      // ✅ Sonido de clic al terminar movimiento en una casilla con acción (Online)
      // Se excluye 'goToStart' porque tiene su propio sonido de "send to home"
      if (token.position > 0) {
        final cell = engine.board.getCell(token.position);
        if (cell.action != null && cell.action!.type != BoardActionType.goToStart) {
          AudioService.playClick();
        }
      }
    } else if (targetPos < token.position || (targetPos - token.position).abs() > 6) {
      if (targetPos == 0 && token.isFinished) {
         _animatingTokens.remove(animKey);
         return;
      }

      int oldPos = token.position;
      await Future.delayed(const Duration(milliseconds: 500));

      if (targetPos >= engine.board.finalPosition || targetPos == -1) {
        token.position = -1;
        token.isFinished = true;
        
        engine.events.add(GameEvent(
          messageKey: 'token_finished_bonus',
          args: {'name': player.name},
          playerId: player.id,
          type: 'bonus'
        ));

        await playFanfare(); // ✅ Bloquea hasta el fin del audio
        _vibrate();
      } else {
        token.position = targetPos;
        
        // ✅ Sonido de clic al teletransportarse a una casilla con acción
        // Se excluye 'goToStart' porque tiene su propio sonido de "send to home"
        if (token.position > 0) {
           final cell = engine.board.getCell(token.position);
           if (cell.action != null && cell.action!.type != BoardActionType.goToStart) {
             AudioService.playClick();
           }
        }

        if (targetPos > 0) {
           engine.events.add(GameEvent(
            messageKey: 'flying_to_cell', 
            args: {'name': player.name, 'cell': targetPos.toString()},
            playerId: player.id,
            type: 'move'
          ));
        }
      }

      if (targetPos == 0) {
        engine.events.add(GameEvent(
          messageKey: 'captured_player',
          args: {'name': player.name, 'other': '?'},
          playerId: player.id,
          type: 'penalty'
        ));

        _capturedTokenController.add(CapturedToken(
          playerIndex: player.index, 
          asset: player.tokenAsset, 
          fromPosition: oldPos
        ));
        await playSendToHomeSound();
        _vibrate();
      }
    }
    
    _animatingTokens.remove(animKey);
    notifyListeners();
  }

  Future<void> _animateRemoteDice(int finalVal, String pid) async {
    rollingDice = true;
    rollingPlayerId = pid;
    notifyListeners();
    
    final player = engine.players.firstWhere((p) => p.id == pid, orElse: () => currentPlayer);

    if (pid != PrefsService.playerId) {
      _playSound(diceAudio, 'sounds/dice.mp3');
    }

    for (int i = 0; i < 10; i++) {
      diceValue = random.nextInt(6) + 1;
      player.lastDiceValue = diceValue; 
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 80));
    }
    
    diceValue = finalVal;
    player.lastDiceValue = finalVal;
    if (diceValue == 6 && pid == PrefsService.playerId) _vibrate();
    
    rollingDice = false;
    rollingPlayerId = null;
    notifyListeners();

    if (pid == PrefsService.playerId) {
        final me = engine.players.firstWhere((p) => p.id == pid, orElse: () => engine.currentPlayer);
        final myMovable = <int>[];
        for (int i = 0; i < me.tokens.length; i++) {
           if (engine.canMoveToken(me, i, finalVal)) myMovable.add(i);
        }

        if (myMovable.isEmpty) {
          _addCantMoveEvent(me);
          if (engine.phase == GamePhase.choosing_token && engine.currentPlayer.id == PrefsService.playerId) {
            Future.delayed(const Duration(seconds: 6), () {
              if (engine.phase == GamePhase.choosing_token && isMyTurn) {
                socketService.send('skip_turn');
              }
            });
          }
        } else {
          if (engine.phase == GamePhase.choosing_token && engine.currentPlayer.id == PrefsService.playerId) {
            movableTokenIds = myMovable;
            _checkAutoMove(forcedByAFK: engine.currentPlayer.isAutoPlaying);
          }
        }
    }
  }

  void _handleChatMessage(Map<String, dynamic> data) {
    final senderId = data['senderId'] ?? '';
    
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
  void sendQuickChat(String message) {
    socketService.send('quick_chat', {'message': message});
    setQuickMessage(PrefsService.playerId, message);
  }

  @override
  void dispose() {
    diceAudio.dispose();
    fanfareAudio.dispose();
    sendToHomeAudio.dispose();
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
