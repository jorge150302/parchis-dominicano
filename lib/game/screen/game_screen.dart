import 'dart:async';
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/language_provider.dart';
import '../logic/game_controller.dart';
import '../logic/game_engine.dart';
import '../logic/level_manager.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/home_zone_widget.dart';
import '../../service/socket_service.dart';
import '../../service/prefs_service.dart';
import '../../service/audio_service.dart';
import '../../service/auth_service.dart';
import '../../service/sync_queue_service.dart';
import '../../models/avatar_icons.dart';

class GameScreen extends StatefulWidget {
  final int playerCount;
  final String? roomCode;
  final List<String>? playerNames;
  final bool isResume;
  final bool isTutorial;

  const GameScreen({
    super.key,
    required this.playerCount,
    this.roomCode,
    this.playerNames,
    this.isResume = false,
    this.isTutorial = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ConfettiController _confettiController;
  bool _isGameFinishedDialogShown = false;
  int _lastFinisherCount = 0; 
  final Set<String> _processedEvents = {};
  final List<ActiveVisualEvent> _activeVisualEvents = [];
  final List<_FlyingToken> _flyingTokens = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription? _captureSubscription;

  int _unreadMessages = 0;
  int _lastMessageCount = 0;
  int? _lastSeconds;

  int _tutorialStep = 0;
  bool _canContinueTutorial = true;

  // Variables para el sistema de niveles
  int _lastGainedXp = 0;
  bool _didLevelUp = false;
  bool _dailyCapReached = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<GameController>();
      controller.addListener(_onGameUpdate);
      _captureSubscription = controller.onTokenCaptured.listen(_onTokenCaptured);

      _lastFinisherCount = controller.engine.finisherIds.length;
      _lastMessageCount = controller.chatMessages.length;
      _lastSeconds = controller.secondsRemaining;

      if (widget.isResume && controller is LocalGameController) {
        final savedJson = PrefsService.savedLocalGame;
        if (savedJson != null) {
          final Map<String, dynamic> state = jsonDecode(savedJson);
          controller.initializeFromResume(state['diceValue'] ?? 1);
        }
      } else if (!controller.isOnline && controller.engine.players.isEmpty) {
        final tokens = ['assets/tokens/red.png', 'assets/tokens/blue.png', 'assets/tokens/green.png', 'assets/tokens/yellow.png'];
        bool vsAI = controller is LocalGameController && controller.vsAI;

        final players = List.generate(
          widget.playerCount,
          (i) {
            String name = (widget.playerNames != null && widget.playerNames!.length > i) 
                ? widget.playerNames![i] 
                : '${context.read<LanguageProvider>().translate('player')} ${i + 1}';
            
            return Player(
              id: '${i + 1}',
              name: name,
              index: i,
              tokenAsset: tokens[i % tokens.length],
              tokenCount: 2,
              isAI: vsAI ? i != 0 : false,
            );
          },
        );
        controller.setPlayers(players);
        controller.startTurn();
      }

      if (widget.isTutorial) {
        setState(() => _tutorialStep = 1);
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _captureSubscription?.cancel();
    super.dispose();
  }

  void _onTokenCaptured(CapturedToken captured) {
    if (!mounted) return;
    final id = const Uuid().v4();
    setState(() {
      _flyingTokens.add(_FlyingToken(
        id: id,
        asset: captured.asset,
        fromCell: captured.fromPosition,
        playerIndex: captured.playerIndex,
      ));
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _flyingTokens.removeWhere((t) => t.id == id);
        });
      }
    });
  }

  void _updatePlayerProgress(GameController controller) {
    if (widget.isTutorial) return;

    final myId = PrefsService.playerId;
    // Si es offline, el ID suele ser "1" para el humano
    final String targetId = controller.isOnline ? myId : "1";
    
    final finisherIds = controller.engine.finisherIds;
    int myPosition = finisherIds.indexOf(targetId);

    if (myPosition != -1) {
      final rawXp = LevelManager.calculateMatchXP(
        position: myPosition,
        totalPlayers: controller.players.length,
      );

      final syncQueue = context.read<SyncQueueService>();
      final int oldLevel = PrefsService.playerLevel;

      _lastGainedXp = syncQueue.awardMatchXp(
        rawXp: rawXp,
        isOnline: controller.isOnline,
      );

      if (PrefsService.playerLevel > oldLevel) {
        _didLevelUp = true;
      }

      // Check if daily offline cap was hit
      if (!controller.isOnline && rawXp > 0 && _lastGainedXp == 0) {
        _dailyCapReached = true;
      }

      // Increment cloud win counter for online first-place
      if (controller.isOnline && myPosition == 0) {
        context.read<AuthService>().incrementWins();
      }
    }
  }

  void _onGameUpdate() {
    if (!mounted) return;
    final controller = context.read<GameController>();

    // ✅ Sonido de alerta de tiempo (cuando quedan 5 segundos y es mi turno)
    if (controller.isOnline && controller.isMyTurn && controller.secondsRemaining == 5 && _lastSeconds != 5) {
      AudioService.playFinalTiming();
    }
    _lastSeconds = controller.secondsRemaining;

    final int currentMsgCount = controller.chatMessages.length;
    if (currentMsgCount > _lastMessageCount) {
      final bool isDrawerOpen = _scaffoldKey.currentState?.isEndDrawerOpen ?? false;
      if (!isDrawerOpen) {
        setState(() {
          _unreadMessages += (currentMsgCount - _lastMessageCount);
        });
      }
      _lastMessageCount = currentMsgCount;
    }

    if (controller.engine.finisherIds.length > _lastFinisherCount) {
      _lastFinisherCount = controller.engine.finisherIds.length;
      _confettiController.stop();
      _confettiController.play();
    }

    final newEvents = controller.consumeEvents();
    for (final event in newEvents) {
      if (!_processedEvents.contains(event.id)) {
        _processedEvents.add(event.id);
        
        final playerIndex = controller.players.indexWhere((p) => p.id == event.playerId);
        if (playerIndex != -1) {
          const alignments = [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight];
          final alignment = alignments[playerIndex % alignments.length];
          
          setState(() {
            _activeVisualEvents.add(ActiveVisualEvent(event: event, alignment: alignment));
          });
          
          // Ajustado de 250ms a 2.5s para coincidir con la duración de la animación visual
          Future.delayed(const Duration(milliseconds: 2500), () {
            if (mounted) {
              setState(() {
                _activeVisualEvents.removeWhere((ae) => ae.event.id == event.id);
              });
            }
          });
        }
      }
    }

    if (controller.engine.phase == GamePhase.finished && !_isGameFinishedDialogShown) {
      _isGameFinishedDialogShown = true;
      _updatePlayerProgress(controller);
      _confettiController.stop();
      _confettiController.play();
      
      // Si subió de nivel, disparamos una segunda ráfaga después de un pequeño delay
      if (_didLevelUp) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _confettiController.play();
        });
      }

      _showGameFinishedDialog();
    }

    if (widget.isTutorial) {
       // Sincronización automática de pasos de MOVIMIENTO inicial para el usuario (pasos 1 y 2)
       if (_tutorialStep == 1 && controller.engine.phase == GamePhase.choosing_token) {
          setState(() => _tutorialStep = 2);
       } else if (_tutorialStep == 2 && controller.engine.phase == GamePhase.idle) {
          Future.delayed(const Duration(milliseconds: 600), () {
             if (mounted && _tutorialStep == 2) {
                setState(() {
                  _tutorialStep = 3;
                  _canContinueTutorial = false;
                });
                // Delay de 2 segundos para permitir que la ficha termine de moverse
                Future.delayed(const Duration(seconds: 2), () {
                   if (mounted) setState(() => _canContinueTutorial = true);
                });
             }
          });
       }
    }

    setState(() {});
  }

  Future<bool> _confirmExit() async {
    final controller = context.read<GameController>();
    if (controller.engine.phase == GamePhase.finished) return true;
    
    String title = context.translate('exit_game_title', listen: false);
    String content = '';

    if (widget.isTutorial) {
      title = context.translate('tutorial_exit_title', listen: false);
      content = context.translate('tutorial_exit_content', listen: false);
    } else {
      final String contentKey = controller.isOnline ? 'exit_online_content' : 'exit_game_content';
      content = context.translate(contentKey, listen: false);
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        title: Text(
          title, 
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: Text(
          content.isEmpty ? "¿Deseas salir?" : content, 
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(context, false);
            },
            child: Text(
              context.translate('stay', listen: false), 
              style: const TextStyle(color: Colors.white70)
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(context, true);
            },
            child: Text(
              context.translate('leave', listen: false), 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final socketSrv = context.watch<SocketService>();
    
    final bool isWaiting = controller.isOnline && controller.players.length < widget.playerCount;
    final bool isReconnecting = controller.isOnline && (!socketSrv.isConnected || socketSrv.isConnecting);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        if (controller.engine.phase == GamePhase.finished) {
           Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
           return;
        }

        if (await _confirmExit() && mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        onEndDrawerChanged: (isOpen) {
          if (isOpen) setState(() => _unreadMessages = 0);
        },
        endDrawer: controller.isOnline ? _ChatDrawer(controller: controller) : null,
        body: Stack(
          children: [
            Positioned.fill(child: Image.asset('assets/images/menu_background.png', fit: BoxFit.cover)),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(socketSrv, controller),
                  Expanded(
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade700,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.brown.shade900, width: 4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))
                              ],
                            ),
                            child: BoardWidget(board: controller.engine.board, players: controller.players),
                          ),
                        ),
                        if (isReconnecting) _buildConnectionOverlay(),
                        ..._buildPlayers(controller),
                        ..._buildFlyingTokens(),
                        _buildFloatingEvents(),
                        if (isWaiting) _buildWaitingOverlay(),
                        if (widget.isTutorial && _tutorialStep > 0) _buildTutorialOverlay(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                  numberOfParticles: 30,
                  gravity: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Alignment _getCellAlignment(int position) {
    if (position == -1) return const Alignment(-0.9, -0.98); // Casilla Fin subida al máximo
    final int index = 100 - position;
    final int row = index ~/ 10;
    final int zigzagCol = index % 10;
    int col;
    if (row % 2 == 0) {
      col = zigzagCol;
    } else {
      col = 9 - zigzagCol;
    }

    return Alignment(
      (col * 0.2) - 0.9,
      (row * 0.2) - 0.88,
    );
  }

  Widget _buildTutorialOverlay() {
    final controller = context.read<GameController>();
    String textKey = '';
    Widget? extra;
    bool isActionStep = false;

    // Se define el color del destello: naranja para el paso final (13), marrón para el resto.
    final Color sparkleColor = _tutorialStep == 13 ? Colors.orange : Colors.brown.shade600;

    final sparkleEffect = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white70,
          ),
        ).animate(onPlay: (c) => c.repeat()).scale(duration: 800.ms, curve: Curves.easeInOut).then().scale(duration: 800.ms),
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: sparkleColor.withValues(alpha: 0.8),
                blurRadius: 20,
                spreadRadius: 8,
              ),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
      ],
    );

    final arrowIndicator = const Icon(Icons.north_west, color: Colors.orangeAccent, size: 80)
        .animate(onPlay: (c) => c.repeat())
        .move(begin: const Offset(20, 20), end: const Offset(0, 0), duration: 600.ms, curve: Curves.easeInOut)
        .then()
        .move(begin: const Offset(0, 0), end: const Offset(20, 20), duration: 600.ms);

    switch (_tutorialStep) {
      case 1:
        textKey = 'tutorial_step_dice_1';
        isActionStep = true;
        extra = Positioned(top: 80, left: 80, child: arrowIndicator);
        break;
      case 2:
        textKey = 'tutorial_step_move_1';
        isActionStep = true;
        extra = Positioned(top: 150, left: 100, child: arrowIndicator);
        break;
      case 3:
        textKey = 'tutorial_step_transition_blue';
        isActionStep = false;
        break;
      case 4:
        textKey = 'tutorial_step_dice_2';
        isActionStep = false;
        break;
      case 5:
        textKey = 'tutorial_step_capture';
        isActionStep = false;
        break;
      case 6:
        textKey = 'tutorial_step_extra_explanation';
        isActionStep = false;
        break;
      case 7:
        textKey = 'tutorial_step_dice_3'; // Explicación del 6 y turno extra
        isActionStep = false;
        break;
      case 8:
        textKey = 'tutorial_step_six_info';
        isActionStep = false;
        break;
      case 9:
        textKey = 'tutorial_step_action_start';
        isActionStep = false;
        extra = Align(alignment: _getCellAlignment(13), child: sparkleEffect);
        break;
      case 10:
        textKey = 'tutorial_step_action_skip';
        isActionStep = false;
        extra = Align(alignment: _getCellAlignment(19), child: sparkleEffect);
        break;
      case 11:
        textKey = 'tutorial_step_action_extra';
        isActionStep = false;
        extra = Align(alignment: _getCellAlignment(15), child: sparkleEffect);
        break;
      case 12:
        textKey = 'tutorial_step_action_move';
        isActionStep = false;
        extra = Align(alignment: _getCellAlignment(24), child: sparkleEffect);
        break;
      case 13:
        textKey = 'tutorial_finish';
        extra = Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: _getCellAlignment(-1),
              child: sparkleEffect,
            ),
            Positioned(
              top: -240, 
              left: 10,
              child: const Icon(Icons.arrow_downward, color: Colors.orangeAccent, size: 85)
                  .animate(onPlay: (c) => c.repeat())
                  .moveY(begin: -30, end: 30, duration: 600.ms)
                  .then()
                  .moveY(begin: 30, end: -30, duration: 600.ms),
            ),
          ],
        );
        break;
    }

    String subtext = '';
    if (_tutorialStep == 1) {
      subtext = context.translate('tutorial_tap_dice_continue', listen: false);
    } else if (_tutorialStep == 2) {
      subtext = context.translate('tutorial_tap_token_continue', listen: false);
    } else if (_tutorialStep == 13) {
      subtext = context.translate('tutorial_finish_sub', listen: false);
    } else {
      subtext = context.translate('tutorial_continue_sub', listen: false);
    }

    return IgnorePointer(
      ignoring: isActionStep,
      child: Stack(
        children: [
          if (extra != null && _tutorialStep >= 9)
             Center(
               child: AspectRatio(
                 aspectRatio: 1,
                 child: extra,
               ),
             )
          else
            extra ?? const SizedBox.shrink(),

          Align(
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () async {
                if (!isActionStep && _canContinueTutorial) {
                  if (_tutorialStep == 3) {
                     setState(() => _tutorialStep = 4);
                  } else if (_tutorialStep == 4) {
                     setState(() {
                        _tutorialStep = 5;
                        _canContinueTutorial = false;
                     });
                     
                     // El azul lanza el dado y mueve para capturar cuando se pasa al paso 5
                     await controller.rollDice();
                     if (controller.movableTokenIds.isNotEmpty) {
                        await controller.selectToken(controller.movableTokenIds.first);
                     }

                     // Delay de 2 segundos para simular movimiento/acción
                     Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _canContinueTutorial = true);
                     });
                  } else if (_tutorialStep == 5) {
                     setState(() => _tutorialStep = 6);
                  } else if (_tutorialStep == 6) {
                     setState(() {
                        _tutorialStep = 7;
                        _canContinueTutorial = false; // Pausa para la animación del 6
                     });
                     
                     // Primer tiro del azul (que debe ser un 6 según el tutorial)
                     await controller.rollDice();
                     if (controller.movableTokenIds.isNotEmpty) {
                        await controller.selectToken(controller.movableTokenIds.first);
                     }

                     // Esperamos a que la ficha avance las 6 posiciones antes de habilitar el siguiente paso
                     Future.delayed(const Duration(milliseconds: 2500), () {
                        if (mounted) setState(() => _canContinueTutorial = true);
                     });
                  } else if (_tutorialStep == 7) {
                     setState(() {
                        _tutorialStep = 8;
                        _canContinueTutorial = false; // El retraso se mueve AQUÍ para esperar el tiro del 1
                     });

                     // Segundo tiro del azul por el turno extra (saca el 1)
                     await controller.rollDice();
                     if (controller.movableTokenIds.isNotEmpty) {
                        await controller.selectToken(controller.movableTokenIds.first);
                     }

                     // Esperamos a que el movimiento del 1 se complete ANTES de habilitar el paso 8
                     Future.delayed(const Duration(milliseconds: 2000), () {
                        if (mounted) setState(() => _canContinueTutorial = true);
                     });
                  } else if (_tutorialStep == 8) {
                     // Al tocar en el paso 8 (ya con la ficha movida), pasamos directamente al 9
                     setState(() => _tutorialStep = 9);
                  } else if (_tutorialStep < 13) {
                     setState(() => _tutorialStep++);
                  } else {
                    Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.all(40),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.brown.shade900,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.orange, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tutorialStep == 13 
                        ? "${context.translate('tutorial_finish', listen: false)}\n\n${context.translate('tutorial_tip', listen: false)}" 
                        : context.translate(textKey, listen: false),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_canContinueTutorial) ...[
                      const SizedBox(height: 20),
                      Text(
                        subtext,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic
                        ),
                      ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
                    ],
                  ],
                ),
              ),
            ),
          ).animate().scale().fadeIn(),
        ],
      ),
    );
  }

  Widget _buildConnectionOverlay() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.brown.shade900,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.orangeAccent, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.orangeAccent, strokeWidth: 3),
              const SizedBox(height: 20),
              Text(
                context.translate('reconnecting'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              const Text(
                "Verificando conexión...",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ).animate().fadeIn().scale(duration: 300.ms, curve: Curves.easeOutBack),
      ),
    );
  }

  List<Widget> _buildFlyingTokens() {
    return _flyingTokens.map((ft) {
      final realIndex = 100 - ft.fromCell;
      final row = realIndex ~/ 10;
      final zigzagCol = realIndex % 10;
      final col = row.isOdd ? (9 - zigzagCol) : zigzagCol;

      final startX = (col - 4.5) * 0.2; 
      final startY = (row - 4.5) * 0.2;

      final targets = [
        const Alignment(-0.9, -0.9), 
        const Alignment(0.9, -0.9),  
        const Alignment(-0.9, 0.9),  
        const Alignment(0.9, 0.9),   
      ];
      final target = targets[ft.playerIndex % targets.length];

      return Center(
        child: FractionalTranslation(
          translation: Offset(startX, startY),
          child: Image.asset(ft.asset, width: 24, height: 24),
        ),
      )
      .animate()
      .move(
        end: Offset(target.x * 150, target.y * 300),
        duration: 800.ms,
        curve: Curves.easeInOutSine,
      )
      .scale(begin: const Offset(1, 1), end: const Offset(0.5, 0.5))
      .fadeOut();
    }).toList();
  }

  Widget _buildFloatingEvents() {
    final Map<Alignment, int> alignmentCounts = {};

    return Stack(
      children: _activeVisualEvents.map((ae) {
        final int count = alignmentCounts[ae.alignment] ?? 0;
        alignmentCounts[ae.alignment] = count + 1;

        final text = context.translate(ae.event.messageKey, args: ae.event.args);
        Color color = Colors.white; 
        IconData icon = Icons.info;
        
        if (ae.event.type == 'penalty') {
          color = Colors.redAccent;
          icon = Icons.warning_amber_rounded;
        } else if (ae.event.type == 'bonus') {
          color = Colors.greenAccent;
          icon = Icons.stars;
        } else if (ae.event.type == 'move') {
          color = Colors.lightBlueAccent;
          icon = Icons.flight_takeoff;
        }

        double offsetX = ae.alignment.x < 0 ? 20 : -20; 
        double offsetY = ae.alignment.y < 0 ? 120 : -120;

        double stackOffset = count * 50.0;
        if (ae.alignment.y > 0) {
          offsetY -= stackOffset; 
        } else {
          offsetY += stackOffset;
        }

        return Align(
          alignment: ae.alignment,
          child: Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.3, end: -0.3, duration: 2.seconds, curve: Curves.easeOut)
            .fadeOut(delay: 1.8.seconds, duration: 400.ms),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(context.translate('waiting_players'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('${context.translate('room_code')}: ${widget.roomCode}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(SocketService socketSrv, GameController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (controller.isOnline)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.chat, color: Colors.white70, size: 22), 
                  onPressed: () {
                    AudioService.playClick();
                    setState(() => _unreadMessages = 0);
                    _scaffoldKey.currentState?.openEndDrawer();
                  }
                ),
                if (_unreadMessages > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_unreadMessages',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ).animate().scale().shake(),
                  ),
              ],
            ),
          IconButton(
            icon: Icon(widget.isTutorial ? Icons.arrow_back : Icons.exit_to_app, color: Colors.white70, size: 22), 
            onPressed: () async {
              AudioService.playClick();
              if (await _confirmExit() && mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
              }
            }
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlayers(GameController controller) {
    const alignments = [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight];
    return List.generate(controller.players.length, (i) {
      return Align(
        alignment: alignments[i % alignments.length], 
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _PlayerCornerWidget(player: controller.players[i]),
        )
      );
    });
  }

  void _showGameFinishedDialog() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final controller = context.read<GameController>();
    final List<String> finisherIds = List.from(controller.engine.finisherIds);
    for (var p in controller.players) {
      if (!finisherIds.contains(p.id)) finisherIds.add(p.id);
    }

    final finishers = finisherIds.map((id) => controller.players.firstWhere((p) => p.id == id)).toList();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), 
          side: const BorderSide(color: Colors.orange, width: 3),
        ),
        title: Center(child: Text(context.translate('podium_title', listen: false), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 24))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Daily Mastery Cap notification
            if (!widget.isTutorial && _dailyCapReached)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent, width: 2),
                ),
                child: const Column(
                  children: [
                    Text(
                      '🏆 Daily Mastery Reached!',
                      style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      "You've maximized your practice XP for today. Take your skills to the Online Arena to continue leveling up and climbing the global ranks!",
                      style: TextStyle(color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // Sección de XP y Nivel MEJORADA con Barra Circular
            if (!widget.isTutorial && _lastGainedXp > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _didLevelUp ? Colors.yellowAccent : Colors.orange.withValues(alpha: 0.3),
                    width: _didLevelUp ? 2 : 1
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Barra circular alrededor del nivel
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 54,
                              height: 54,
                              child: CircularProgressIndicator(
                                value: LevelManager.getLevelProgress(PrefsService.totalXp),
                                strokeWidth: 5,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(_didLevelUp ? Colors.yellowAccent : Colors.orange),
                              ),
                            ),
                            Text(
                              "${PrefsService.playerLevel}",
                              style: const TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold, 
                                fontSize: 18
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LevelManager.getRankName(PrefsService.playerLevel).toUpperCase(),
                                style: TextStyle(
                                  color: _didLevelUp ? Colors.yellowAccent : Colors.orange, 
                                  fontWeight: FontWeight.w900, 
                                  fontSize: 16,
                                  letterSpacing: 1.2
                                ),
                              ),
                              const Text(
                                "Nivel Actual",
                                style: TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: Text(
                            "+$_lastGainedXp XP",
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Indicador de cuánto falta
                    if (!_didLevelUp && PrefsService.playerLevel < 100)
                      Text(
                        "Faltan ${LevelManager.xpRequiredForLevel(PrefsService.playerLevel) - (PrefsService.totalXp % LevelManager.xpRequiredForLevel(PrefsService.playerLevel))} XP para el nivel ${PrefsService.playerLevel + 1}",
                        style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    
                    if (_didLevelUp)
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Column(
                          children: [
                            const Text(
                              "¡NUEVO RANGO ALCANZADO!",
                              style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.w900, fontSize: 18),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1)),
                            const Icon(Icons.stars, color: Colors.yellowAccent, size: 30),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            
            // Lista de finalistas
            ...finishers.asMap().entries.map((entry) {
              int idx = entry.key;
              Player p = entry.value;
              return ListTile(
                leading: Text('${idx + 1}°', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                title: Text(
                  p.name, 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Image.asset(p.tokenAsset, width: 30),
              );
            }),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
              onPressed: () {
                AudioService.playClick();
                Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
              },
              child: Text(context.translate('back_to_menu', listen: false), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _ChatDrawer extends StatefulWidget {
  final GameController controller;
  const _ChatDrawer({required this.controller});

  @override
  State<_ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<_ChatDrawer> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.7, 
      backgroundColor: Colors.orange.shade50, 
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.brown.shade800, 
                border: const Border(bottom: BorderSide(color: Colors.white24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.orangeAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.translate('multiplayer_online'), 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                    onPressed: () {
                      AudioService.playClick();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: widget.controller.chatMessages.length,
                itemBuilder: (context, index) {
                  final msg = widget.controller.chatMessages[index];
                  final bool isMe = msg.senderId == PrefsService.playerId;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe) 
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Text(msg.sender, style: TextStyle(color: Colors.brown.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.orange.shade700 : Colors.white, 
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
                            ),
                            border: isMe ? null : Border.all(color: Colors.orange.shade100, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Text(
                            msg.message, 
                            style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 13)
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.brown.shade50, 
                border: Border(top: BorderSide(color: Colors.orange.shade200, width: 2.0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade300, width: 2.0),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: context.translate('chat_input_hint'),
                          hintStyle: const TextStyle(color: Colors.black38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade700,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 16),
                      onPressed: () {
                        AudioService.playClick();
                        _sendMessage();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.controller.sendChatMessage(text);
      _textController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }
}

class _PlayerCornerWidget extends StatelessWidget {
  final Player player;
  const _PlayerCornerWidget({required this.player});

  void _showPlayerOptions(BuildContext context, GameController controller) {
    if (player.id == PrefsService.playerId || player.isAI) return;

    AudioService.playClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.brown.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              controller.blockedPlayerIds.contains(player.id) ? Icons.person : Icons.person_off, 
              color: Colors.white
            ),
            title: Text(
              controller.blockedPlayerIds.contains(player.id) 
                  ? context.translate('unblock_player', listen: false) 
                  : context.translate('block_player', listen: false),
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              AudioService.playClick();
              controller.toggleBlockPlayer(player.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(context.translate(
                  controller.blockedPlayerIds.contains(player.id) ? 'player_blocked' : 'player_unblocked',
                  listen: false
                )),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.redAccent),
            title: Text(context.translate('report_player', listen: false), style: const TextStyle(color: Colors.redAccent)),
            onTap: () {
              AudioService.playClick();
              Navigator.pop(context);
              _showReportReasons(context, controller);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showReportReasons(BuildContext context, GameController controller) {
    final reasons = ['offensive_language', 'inappropriate_name', 'cheating', 'other'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        title: Text(context.translate('report_reason', listen: false), style: const TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(context.translate(r, listen: false), style: const TextStyle(color: Colors.white)),
            onTap: () {
              AudioService.playClick();
              controller.reportPlayer(player.id, r);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('report_sent', listen: false))));
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showQuickChat(BuildContext context, GameController controller) {
    AudioService.playClick();
    final options = [
      "quick_msg_good_game", 
      "quick_msg_oops", 
      "🤣", 
      "👍", 
      "quick_msg_hello", 
      "💤", 
      "quick_msg_play_fast"
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.brown.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisExtent: 60,
          ),
          itemCount: options.length,
          itemBuilder: (context, idx) => InkWell(
            onTap: () {
              AudioService.playClick();
              controller.sendQuickChat(options[idx]);
              Navigator.pop(context);
            },
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Text(
                  context.translate(options[idx], listen: false),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar(Player player, double size) {
    if (player.avatarType == 'icon') {
      final icon = avatarIconById(player.avatarIconId);
      if (icon != null) {
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: icon.color,
          child: Icon(icon.icon, color: Colors.white, size: size * 0.65),
        );
      }
    }
    return Image.asset(player.tokenAsset, width: size, height: size);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final socketSrv = context.watch<SocketService>();
    final bool isMe = controller.isOnline ? player.id == PrefsService.playerId : !player.isAI;
    final bool isTurn = controller.currentPlayer.id == player.id;
    final bool isRolling = controller.rollingDice && controller.rollingPlayerId == player.id;
    final bool canTap = isTurn && isMe && controller.engine.phase == GamePhase.idle && !controller.rollingDice;
    final bool isBlocked = controller.blockedPlayerIds.contains(player.id);
    final String? activeMessage = controller.playerQuickMessages[player.id];

    // ✅ Modificado de 5 a 6 para que empiece a ser rojo a partir del segundo 5 (inclusive)
    final bool isCriticalTime = isTurn && controller.isOnline && controller.secondsRemaining < 6;
    final Color timerColor = isCriticalTime ? Colors.red : Colors.orangeAccent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onLongPress: controller.isOnline ? () => _showPlayerOptions(context, controller) : null,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 140), 
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isTurn ? (isCriticalTime ? Colors.red : Colors.orange) : Colors.black45, 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isBlocked ? Colors.red : Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPlayerAvatar(player, 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    if (isBlocked) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.block, size: 14, color: Colors.red),
                    ],
                    if (controller.isOnline && !player.isConnected) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.flash_off, size: 14, color: Colors.redAccent).animate(onPlay: (c) => c.repeat()).shake(),
                    ]
                  ],
                ),
              ),
            ),
            
            if (activeMessage != null)
              Positioned(
                top: -40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      context.translate(activeMessage, listen: false),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack).shake(delay: 200.ms),
                ),
              ),

            if (isMe && controller.isOnline)
              Positioned(
                top: -12,
                right: -12,
                child: GestureDetector(
                  onTap: () => _showQuickChat(context, controller),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.insert_emoticon, size: 18, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4), 
        
        if (!player.isFinished)
          GestureDetector(
            onTap: () {
               if (canTap) {
                 // ✅ Eliminado AudioService.playClick() para evitar duplicación con sounds/dice.mp3
                 if (controller.isOnline && !socketSrv.isConnected) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Sin conexión"), duration: Duration(seconds: 1))
                   );
                   return;
                 }
                 controller.rollDice();
               }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.isOnline && !player.isConnected)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8)),
                        child: const Text("OFFLINE", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ),

                  if (isMe && (isTurn || player.isAutoPlaying))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: player.isAutoPlaying
                        ? GestureDetector(
                            onTap: () {
                              AudioService.playClick();
                              controller.toggleAutoPlay(false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("AUTO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 4),
                                  Icon(Icons.check_box, color: Colors.white, size: 14),
                                ],
                              ),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                          )
                        : Text(
                            context.translate('your_turn'),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                          ).animate(onPlay: (c) => c.repeat()).fadeIn(duration: 600.ms).then().fadeOut(duration: 600.ms),
                    ),

                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4), 
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (isTurn && controller.isOnline)
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: CircularProgressIndicator(
                            value: controller.turnProgress,
                            strokeWidth: 4,
                            color: timerColor,
                            backgroundColor: Colors.white10,
                          ),
                        ).animate(target: isCriticalTime ? 1 : 0, onPlay: (c) => c.repeat())
                         .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 500.ms, curve: Curves.easeInOut)
                         .then()
                         .scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1), duration: 500.ms, curve: Curves.easeInOut),
                      DiceWidget(
                        value: player.lastDiceValue,
                        rolling: isRolling,
                        style: const DiceStyle(sides: 6, size: 50, assetPath: 'assets/dice/classic'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          const SizedBox(height: 58), 

        const SizedBox(height: 8),
        HomeZoneWidget(player: player),
      ],
    );
  }
}

class ActiveVisualEvent {
  final GameEvent event;
  final Alignment alignment;
  ActiveVisualEvent({required this.event, required this.alignment});
}

class _FlyingToken {
  final String id;
  final String asset;
  final int fromCell;
  final int playerIndex;
  _FlyingToken({required this.id, required this.asset, required this.fromCell, required this.playerIndex});
}
