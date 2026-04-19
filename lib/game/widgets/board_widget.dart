import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/board.dart';
import '../models/player.dart';
import '../models/cell.dart';
import '../models/board_action.dart'; 
import '../logic/game_controller.dart';
import '../logic/game_engine.dart';
import '../../config/language_provider.dart';

class BoardWidget extends StatefulWidget {
  final Board board;
  final List<Player> players;

  const BoardWidget({
    super.key,
    required this.board,
    required this.players,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  static const int columns = 10;
  final Map<int, GlobalKey> _cellKeys = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i <= widget.board.finalPosition; i++) {
      _cellKeys[i] = GlobalKey();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final cells = widget.board.cells.reversed.toList();

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
            ),
            itemBuilder: (_, visualIndex) {
              final row = visualIndex ~/ columns;
              final col = visualIndex % columns;
              final zigzagCol = row.isOdd ? (columns - 1 - col) : col;
              final realIndex = row * columns + zigzagCol;
              final cell = cells[realIndex];

              return _StaticCell(
                key: _cellKeys[cell.number],
                cell: cell,
                finalPosition: widget.board.finalPosition,
                controller: controller,
              );
            },
          ),
          ..._buildAnimatedTokens(controller),
        ],
      ),
    );
  }

  List<Widget> _buildAnimatedTokens(GameController controller) {
    final List<Widget> animatedTokens = [];
    final Map<int, List<Map<String, dynamic>>> cellGroups = {};

    for (var player in widget.players) {
      for (var token in player.tokens) {
        if (token.position > 0 && token.position < widget.board.finalPosition && !token.isFinished) {
          cellGroups.putIfAbsent(token.position, () => []).add({
            'player': player,
            'token': token,
          });
        }
      }
    }

    cellGroups.forEach((pos, tokens) {
      final bool isBlockade = tokens.length == 2 && tokens[0]['player'].id == tokens[1]['player'].id;
      
      for (int i = 0; i < tokens.length; i++) {
        final player = tokens[i]['player'] as Player;
        final token = tokens[i]['token'] as Token;
        
        animatedTokens.add(
          _TokenObserver(
            key: ValueKey("token_${player.id}_${token.id}"),
            cellKey: _cellKeys[pos]!,
            player: player,
            token: token,
            index: i,
            total: tokens.length,
            isBlockade: isBlockade,
            controller: controller,
          ),
        );
      }
    });

    return animatedTokens;
  }
}

class _StaticCell extends StatelessWidget {
  final Cell cell;
  final int finalPosition;
  final GameController controller;

  const _StaticCell({
    super.key,
    required this.cell,
    required this.finalPosition,
    required this.controller,
  });

  String _getCellLabel(BuildContext context, Cell cell) {
    if (cell.number == 0) return context.translate('board_start');
    if (cell.number == finalPosition) return context.translate('board_finish');
    final action = cell.action;
    if (action != null) {
      switch (action.type) {
        case BoardActionType.goToStart: return context.translate('board_go_to_start');
        case BoardActionType.moveTo: return context.translate('board_move_to', args: {'target': '${action.targetNumber ?? ''}'});
        case BoardActionType.skipTurn: return context.translate('board_skip_turn');
        case BoardActionType.rollAgain: return context.translate('board_extra_turn');
      }
    }
    return cell.number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final hasAction = cell.action != null;
    final label = _getCellLabel(context, cell);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: hasAction
            ? const LinearGradient(colors: [Color(0xffffd180), Color(0xffffb74d)])
            : const LinearGradient(colors: [Colors.white, Color(0xffeeeeee)]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.black45),
        ),
      ),
    );
  }
}

class _TokenObserver extends StatelessWidget {
  final GlobalKey cellKey;
  final Player player;
  final Token token;
  final int index;
  final int total;
  final bool isBlockade;
  final GameController controller;

  const _TokenObserver({
    super.key,
    required this.cellKey,
    required this.player,
    required this.token,
    required this.index,
    required this.total,
    required this.isBlockade,
    required this.controller,
  });

  Offset _getOffset(BuildContext context) {
    final RenderBox? cellBox = cellKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? boardBox = context.findAncestorRenderObjectOfType<RenderBox>();
    
    if (cellBox != null && boardBox != null) {
      final cellPos = cellBox.localToGlobal(Offset.zero, ancestor: boardBox);
      final cellSize = cellBox.size;
      
      double offsetX = 0;
      double offsetY = 0;

      if (total > 1) {
        final align = _getTokenAlignment(index, total, isBlockade);
        offsetX = align.x * (cellSize.width * 0.25);
        offsetY = align.y * (cellSize.height * 0.25);
      }

      return Offset(
        cellPos.dx + (cellSize.width / 2) - 10 + offsetX, 
        cellPos.dy + (cellSize.height / 2) - 10 + offsetY
      );
    }
    return Offset.zero;
  }

  Alignment _getTokenAlignment(int index, int total, bool isBlockade) {
    if (total == 1) return Alignment.center;
    if (total == 2) {
      if (isBlockade) return index == 0 ? const Alignment(-0.5, -0.4) : const Alignment(0.45, 0.4);
      return index == 0 ? const Alignment(-0.5, 0.5) : const Alignment(0.5, -0.5);
    }
    switch (index) {
      case 0: return const Alignment(-0.5, -0.5);
      case 1: return const Alignment(0.5, -0.5);
      case 2: return const Alignment(-0.5, 0.5);
      case 3: return const Alignment(0.5, 0.5);
      default: return Alignment.center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelectable = controller.engine.phase == GamePhase.choosing_token &&
        controller.currentPlayer.id == player.id &&
        controller.movableTokenIds.contains(token.id);

    final targetOffset = _getOffset(context);

    return TweenAnimationBuilder<Offset>(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      tween: Tween<Offset>(end: targetOffset),
      builder: (context, offset, child) {
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: _TokenStepAnimation(
            position: token.position,
            child: TokenWidget(
              asset: player.tokenAsset,
              isSelectable: isSelectable,
              size: isBlockade ? 18.0 : (total > 1 ? 17.0 : 20.0),
              isBlockade: isBlockade,
              onTap: isSelectable ? () {
                controller.selectToken(token.id);
              } : null,
            ),
          ),
        );
      },
    );
  }
}

class _TokenStepAnimation extends StatefulWidget {
  final int position;
  final Widget child;
  const _TokenStepAnimation({required this.position, required this.child});

  @override
  State<_TokenStepAnimation> createState() => _TokenStepAnimationState();
}

class _TokenStepAnimationState extends State<_TokenStepAnimation> {
  int? _lastPos;

  @override
  Widget build(BuildContext context) {
    final bool didMove = _lastPos != null && _lastPos != widget.position;
    _lastPos = widget.position;

    if (didMove) {
      return widget.child
          .animate(key: ValueKey("jump_${widget.position}"))
          .moveY(begin: 0, end: -12, duration: 90.ms, curve: Curves.easeOut)
          .then()
          .moveY(begin: -12, end: 0, duration: 90.ms, curve: Curves.easeIn);
    }
    return widget.child;
  }
}

class TokenWidget extends StatelessWidget {
  final String asset;
  final bool isSelectable;
  final double size;
  final bool isBlockade;
  final VoidCallback? onTap;

  const TokenWidget({
    super.key,
    required this.asset,
    required this.isSelectable,
    this.size = 20.0,
    this.isBlockade = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget token = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (isSelectable)
              const BoxShadow(color: Colors.yellow, blurRadius: 10, spreadRadius: 2),
            const BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))
          ],
        ),
        child: Image.asset(asset, width: size, height: size),
      ),
    );

    if (isSelectable) {
      return token
          .animate(onPlay: (c) => c.repeat())
          .moveY(begin: 0, end: -4, duration: 500.ms, curve: Curves.easeInOut)
          .then()
          .moveY(begin: -4, end: 0, duration: 500.ms, curve: Curves.easeInOut)
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: Colors.yellow.withValues(alpha: 0.3));
    }

    if (isBlockade) {
      return token.animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1200.ms, curve: Curves.easeInOut);
    }

    return token;
  }
}
