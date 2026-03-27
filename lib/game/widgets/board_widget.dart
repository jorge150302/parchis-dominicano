import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/board.dart';
import '../models/player.dart';
import '../models/cell.dart';
import '../models/board_action.dart'; 
import '../logic/game_controller.dart';
import '../logic/game_engine.dart';

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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final cells = widget.board.cells.reversed.toList();

    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
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

          final List<Map<String, dynamic>> tokensInCell = [];
          for (var player in widget.players) {
            for (var token in player.tokens) {
              if (token.position == cell.number && !token.isFinished && token.position > 0) {
                tokensInCell.add({
                  'player': player,
                  'token': token,
                });
              }
            }
          }

          return _AnimatedCell(
            cell: cell,
            tokensInCell: tokensInCell,
            finalPosition: widget.board.finalPosition,
            controller: controller,
          );
        },
      ),
    );
  }
}

class _AnimatedCell extends StatelessWidget {
  final Cell cell;
  final List<Map<String, dynamic>> tokensInCell;
  final int finalPosition;
  final GameController controller;

  const _AnimatedCell({
    required this.cell,
    required this.tokensInCell,
    required this.finalPosition,
    required this.controller,
  });

  String _getCellLabel(Cell cell) {
    if (cell.number == 0) return 'Inicio';
    if (cell.number == finalPosition) return 'Fin';

    final action = cell.action;
    if (action != null) {
      switch (action.type) {
        case BoardActionType.goToStart:
          return 'INICIO';
        case BoardActionType.moveTo:
          return 'Al ${action.targetNumber ?? ''}';
        case BoardActionType.skipTurn:
          return '1 turno sin jugar';
        case BoardActionType.rollAgain:
          return 'Juegue otra vez';
      }
    }
    return cell.number.toString();
  }

  Alignment _getTokenAlignment(int index, int total, bool isBlockade) {
    if (total == 1) return Alignment.center;
    if (total == 2) {
      if (isBlockade) {
        return index == 0 ? const Alignment(-0.5, -0.4) : const Alignment(0.45, 0.4);
      }
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
    final hasAction = cell.action != null;
    final label = _getCellLabel(cell);
    final int totalTokens = tokensInCell.length;

    final bool isBlockade = totalTokens == 2 &&
        tokensInCell[0]['player'].id == tokensInCell[1]['player'].id;

    final double tokenSize = isBlockade ? 18.0 : (totalTokens > 1 ? 17.0 : 20.0);

    final selectableTokens = tokensInCell.where((data) {
      final Player p = data['player'];
      final Token t = data['token'];
      return controller.engine.phase == GamePhase.choosing_token &&
             controller.currentPlayer.id == p.id &&
             controller.movableTokenIds.contains(t.id);
    }).toList();

    final bool canTapCell = selectableTokens.length == 1;

    return GestureDetector(
      onTap: canTapCell ? () => controller.selectToken(selectableTokens.first['token'].id) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: hasAction
              ? const LinearGradient(colors: [Color(0xffffd180), Color(0xffffb74d)])
              : const LinearGradient(colors: [Colors.white, Color(0xffeeeeee)]),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(1, 1)),
          ],
          border: Border.all(color: Colors.black12, width: 0.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Opacity(
                opacity: isBlockade ? 0.1 : 1.0,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black38,
                  ),
                ),
              ),
            ),
            ...tokensInCell.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> data = entry.value;
              final Player player = data['player'];
              final Token token = data['token'];

              final bool isSelectable = controller.engine.phase == GamePhase.choosing_token &&
                  controller.currentPlayer.id == player.id &&
                  controller.movableTokenIds.contains(token.id);

              return Align(
                alignment: _getTokenAlignment(index, totalTokens, isBlockade),
                child: TokenWidget(
                  asset: player.tokenAsset,
                  isSelectable: isSelectable,
                  size: tokenSize,
                  isBlockade: isBlockade,
                  onTap: isSelectable ? () => controller.selectToken(token.id) : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
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
              BoxShadow(
                color: Colors.yellow.withOpacity(0.7),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            const BoxShadow(
              color: Colors.black26,
              blurRadius: 3,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Image.asset(
          asset,
          width: size,
          height: size,
        ),
      ),
    );

    if (isSelectable) {
      return token
          .animate(onPlay: (c) => c.repeat())
          .moveY(begin: 0, end: -4, duration: 500.ms, curve: Curves.easeInOut)
          .then()
          .moveY(begin: -4, end: 0, duration: 500.ms, curve: Curves.easeInOut)
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: Colors.yellow.withOpacity(0.3));
    }

    if (isBlockade) {
      return token.animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05),
            duration: 1200.ms,
            curve: Curves.easeInOut
          );
    }

    return token;
  }
}
