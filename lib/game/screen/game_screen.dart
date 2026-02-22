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

class GameScreen extends StatefulWidget {
  final int playerCount;

  const GameScreen({
    super.key,
    required this.playerCount,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final ConfettiController _confettiController;
  final Set<String> _announcedWinners = {};
  bool _isGameFinishedDialogShown = false;
  final Set<String> _processedEvents = {};

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    Future.microtask(() {
      final controller = context.read<GameController>();

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
          tokenAsset: tokens[i % tokens.length],
        ),
      );

      controller.setPlayers(players);
      controller.addListener(_onGameUpdate);
      controller.startTurn();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    if (mounted) {
      context.read<GameController>().removeListener(_onGameUpdate);
    }
    super.dispose();
  }

  void _onGameUpdate() {
    if (!mounted) return;

    final controller = context.read<GameController>();
    final engine = controller.engine;

    final newEvents = controller.consumeEvents();
    for (final event in newEvents) {
      if (!_processedEvents.contains(event.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event.message),
            duration: const Duration(seconds: 2),
          ),
        );
        _processedEvents.add(event.id);
      }
    }

    for (final player in engine.finishedPlayers) {
      if (!_announcedWinners.contains(player.id)) {
        _announcedWinners.add(player.id);

        if (engine.phase != GamePhase.finished) {
          _confettiController.play();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡${player.name} ha llegado a la meta!'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }

    if (engine.phase == GamePhase.finished && !_isGameFinishedDialogShown) {
      _isGameFinishedDialogShown = true;
      _confettiController.play();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameFinishedDialog();
      });
    }

    setState(() {});
  }

  Future<void> _showGameFinishedDialog() async {
    final controller = context.read<GameController>();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Resultados Finales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (int i = 0; i < controller.engine.finishedPlayers.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${i + 1}° - ${controller.engine.finishedPlayers[i].name}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(
                      controller.engine.finishedPlayers[i].tokenAsset,
                      width: 20,
                      height: 20,
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/menu', (route) => false);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar partida'),
        content: const Text(
            '¿Deseas terminar la partida? Si sales ahora, la partida finalizará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _showExitConfirmationDialog(context);
        if (shouldExit && mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/menu', (route) => false);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/menu_background.png',
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple
                ],
                numberOfParticles: 30,
                maxBlastForce: 20,
                minBlastForce: 5,
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade700,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.brown.shade900,
                          width: 6,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 18,
                            color: Colors.black45,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: BoardWidget(
                        board: controller.engine.board,
                        players: controller.players,
                      ),
                    ),
                  ),
                  ..._buildPlayers(controller),
                  if (controller.engine.finishedPlayers.isNotEmpty &&
                      controller.engine.phase != GamePhase.finished)
                    _buildRanking(controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRanking(GameController controller) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Ranking:',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 4),
              for (int i = 0; i < controller.engine.finishedPlayers.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        '${i + 1}° - ${controller.engine.finishedPlayers[i].name}',
                        style: const TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 8),
                    Image.asset(controller.engine.finishedPlayers[i].tokenAsset, width: 20),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPlayers(GameController controller) {
    final players = controller.players;
    const positions = [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ];

    return List.generate(players.length, (i) {
      final player = players[i];
      return Align(
        alignment: positions[i % positions.length],
        child: _PlayerCornerWidget(player: player),
      );
    });
  }
}

class _PlayerCornerWidget extends StatelessWidget {
  final Player player;

  const _PlayerCornerWidget({
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final isTurn = controller.currentPlayer.id == player.id;
    final rollingThisDice = controller.rollingDice && isTurn;
    final canRoll = isTurn && !controller.rollingDice && !player.mustSkipTurn;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isTurn ? Colors.orange : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(player.tokenAsset, width: 22, height: 22),
                const SizedBox(width: 6),
                Text(
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: canRoll ? controller.rollDice : null,
            child: Opacity(
              opacity: isTurn && !player.mustSkipTurn ? 1 : 0.35,
              child: DiceWidget(
                key: ValueKey(player.id),
                value: controller.diceValue,
                rolling: rollingThisDice,
                style: const DiceStyle(
                  sides: 6,
                  assetPath: 'assets/dice/classic',
                  size: 60,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          HomeZoneWidget(player: player),
        ],
      ),
    );
  }
}
