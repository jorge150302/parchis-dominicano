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
import '../models/game_event.dart';
import '../models/player.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/home_zone_widget.dart';
import '../../service/socket_service.dart';
import '../../service/prefs_service.dart';
import '../../service/audio_service.dart'; // ✅ Importación añadida

class GameScreen extends StatefulWidget {
  final int playerCount;
  final String? roomCode;
  final List<String>? playerNames;
  final bool isResume;

  const GameScreen({
    super.key,
    required this.playerCount,
    this.roomCode,
    this.playerNames,
    this.isResume = false,
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

  // ✅ Variables para el Chat
  int _unreadMessages = 0;
  int _lastMessageCount = 0;

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

  void _onGameUpdate() {
    if (!mounted) return;
    final controller = context.read<GameController>();

    // ✅ Lógica de mensajes no leídos
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
      _confettiController.stop();
      _confettiController.play();
      _showGameFinishedDialog();
    }
    setState(() {});
  }

  Future<bool> _confirmExit() async {
    final controller = context.read<GameController>();
    if (controller.engine.phase == GamePhase.finished) return true;
    
    if (controller.isOnline) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        title: Text(
          context.translate('exit_game_title'), 
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.translate('exit_game_content'), 
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick(); // ✅ Sonido añadido
              Navigator.pop(context, false);
            },
            child: Text(context.translate('stay'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AudioService.playClick(); // ✅ Sonido añadido
              Navigator.pop(context, true);
            },
            child: Text(context.translate('leave'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                numberOfParticles: 30,
                gravity: 0.1,
              ),
            ),
          ],
        ),
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
                    AudioService.playClick(); // ✅ Sonido añadido
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
            icon: const Icon(Icons.exit_to_app, color: Colors.white70, size: 22), 
            onPressed: () async {
              AudioService.playClick(); // ✅ Sonido añadido
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), 
          side: const BorderSide(color: Colors.orange, width: 3),
        ),
        title: Center(child: Text(context.translate('podium_title'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 24))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: finishers.asMap().entries.map((entry) {
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
          }).toList(),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
              onPressed: () {
                AudioService.playClick(); // ✅ Sonido añadido
                Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
              },
              child: Text(context.translate('back_to_menu'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
            // Header del Chat
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
                  // ✅ Botón para cerrar el chat
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 24),
                    onPressed: () {
                      AudioService.playClick(); // ✅ Sonido añadido
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            
            // Lista de Mensajes
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
                            border: isMe ? null : Border.all(color: Colors.orange.shade100, width: 1.5), // ✅ Borde más ancho
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
            
            // Area de Entrada
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.brown.shade50, 
                border: Border(top: BorderSide(color: Colors.orange.shade200, width: 2.0)), // ✅ Línea superior más ancha
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.shade300, width: 2.0), // ✅ Borde del input más ancho
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: context.translate('chat_input_hint'), // ✅ TRADUCCIÓN APLICADA
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
                        AudioService.playClick(); // ✅ Sonido añadido
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

    AudioService.playClick(); // ✅ Sonido al abrir opciones
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
                  ? context.translate('unblock_player') 
                  : context.translate('block_player'),
              style: const TextStyle(color: Colors.white),
            ),
            onTap: () {
              AudioService.playClick(); // ✅ Sonido añadido
              controller.toggleBlockPlayer(player.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(context.translate(
                  controller.blockedPlayerIds.contains(player.id) ? 'player_blocked' : 'player_unblocked'
                )),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.report, color: Colors.redAccent),
            title: Text(context.translate('report_player'), style: const TextStyle(color: Colors.redAccent)),
            onTap: () {
              AudioService.playClick(); // ✅ Sonido añadido
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
        title: Text(context.translate('report_reason'), style: const TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(context.translate(r), style: const TextStyle(color: Colors.white)),
            onTap: () {
              AudioService.playClick(); // ✅ Sonido añadido
              controller.reportPlayer(player.id, r);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.translate('report_sent'))));
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showQuickChat(BuildContext context, GameController controller) {
    AudioService.playClick(); // ✅ Sonido al abrir emojis
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
              AudioService.playClick(); // ✅ Sonido añadido
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
                  context.translate(options[idx]),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    final bool isCriticalTime = isTurn && controller.isOnline && controller.secondsRemaining < 5;
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
                    Image.asset(player.tokenAsset, width: 14, height: 14),
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
                      context.translate(activeMessage),
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
                 AudioService.playClick(); // ✅ Sonido añadido
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
                              AudioService.playClick(); // ✅ Sonido añadido
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
                        : const Text(
                            "TU TURNO",
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
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
