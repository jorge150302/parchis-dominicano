import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/game_controller.dart';
import '../logic/game_engine.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../widgets/board_widget.dart';
import '../widgets/dice_widget.dart';
import '../widgets/home_zone_widget.dart';
import '../../service/socket_service.dart';

class GameScreen extends StatefulWidget {
  final int playerCount;
  final String? roomCode;

  const GameScreen({
    super.key,
    required this.playerCount,
    this.roomCode,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ConfettiController _confettiController;
  final Set<String> _announcedWinners = {};
  bool _isGameFinishedDialogShown = false;
  final Set<String> _processedEvents = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    Future.microtask(() {
      final controller = context.read<GameController>();
      controller.addListener(_onGameUpdate);

      if (controller.engine.players.isEmpty) {
        final tokens = [
          'assets/tokens/red.png',
          'assets/tokens/blue.png',
          'assets/tokens/green.png',
          'assets/tokens/yellow.png',
        ];

        final players = List.generate(
          widget.playerCount,
          (i) => Player(
            id: '${i + 1}',
            name: 'Jugador ${i + 1}',
            index: i,
            tokenAsset: tokens[i % tokens.length],
          ),
        );
        controller.setPlayers(players);
        controller.startTurn();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _chatScrollController.dispose();
    if (mounted) {
      context.read<GameController>().removeListener(_onGameUpdate);
    }
    super.dispose();
  }

  void _onGameUpdate() {
    if (!mounted) return;

    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isConnected = context.watch<SocketService>().isConnected;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit && mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: controller.isOnline ? _buildChatDrawer(controller) : null,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/menu_background.png', fit: BoxFit.cover),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Solo mostramos la TopBar si es ONLINE
                  if (controller.isOnline) 
                    _buildTopBar(isConnected, controller),
                  
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
                              boxShadow: const [BoxShadow(blurRadius: 15, color: Colors.black45)],
                            ),
                            child: BoardWidget(
                              board: controller.engine.board,
                              players: controller.players,
                            ),
                          ),
                        ),
                        ..._buildPlayers(controller),
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
                numberOfParticles: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isConnected, GameController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black26,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'EN LÍNEA' : 'DESCONECTADO',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          if (widget.roomCode != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'SALA: ${widget.roomCode}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),

          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat, color: Colors.white70),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  if (controller.chatMessages.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${controller.chatMessages.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.white70),
                onPressed: () async {
                  if (await _showExitConfirmationDialog(context)) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
                  }
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChatDrawer(GameController controller) {
    final TextEditingController chatInputController = TextEditingController();

    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange,
            child: const Row(
              children: [
                Icon(Icons.chat, color: Colors.white),
                SizedBox(width: 10),
                Text('Chat en Vivo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(8),
              itemCount: controller.chatMessages.length,
              itemBuilder: (context, index) {
                final msg = controller.chatMessages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(msg.sender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                        child: Text(msg.message),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: chatInputController,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        controller.sendChatMessage(value.trim());
                        chatInputController.clear();
                      }
                    },
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje...', border: OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.orange),
                  onPressed: () {
                    final text = chatInputController.text.trim();
                    if (text.isNotEmpty) {
                      controller.sendChatMessage(text);
                      chatInputController.clear();
                    }
                  },
                ),
              ],
            ),
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
        child: _PlayerCornerWidget(player: controller.players[i]),
      );
    });
  }

  Future<void> _showGameFinishedDialog() async {
    final controller = context.read<GameController>();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('¡Partida Finalizada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: controller.engine.finishedPlayers.asMap().entries.map((e) =>
            ListTile(
              leading: Text('${e.key + 1}°'),
              title: Text(e.value.name),
              trailing: Image.asset(e.value.tokenAsset, width: 24),
            )
          ).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false), child: const Text('Volver al Menú')),
        ],
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir de la partida?'),
        content: const Text('Perderás el progreso actual.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Salir')),
        ],
      )
    ) ?? false;
  }
}

class _PlayerCornerWidget extends StatelessWidget {
  final Player player;
  const _PlayerCornerWidget({required this.player});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isTurn = controller.currentPlayer.id == player.id;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isTurn ? Colors.orange.withValues(alpha: 0.9) : Colors.black45,
              borderRadius: BorderRadius.circular(12),
              border: isTurn ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(player.tokenAsset, width: 20, height: 20),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (player.isAI)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('(IA)', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isTurn && !controller.rollingDice && !player.isAI ? controller.rollDice : null,
            child: Opacity(
              opacity: player.isAI ? 0.5 : 1.0,
              child: DiceWidget(
                value: controller.diceValue,
                rolling: controller.rollingDice && isTurn,
                style: const DiceStyle(
                  sides: 6,
                  size: 55, 
                  assetPath: 'assets/dice/classic'
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          HomeZoneWidget(player: player),
        ],
      ),
    );
  }
}
