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

  double _getFontSize(String label, bool hasAction) {
    if (hasAction) {
      if (label == '1 turno sin jugar' || label == 'Juegue otra vez') return 7.5;
      if (label == 'INICIO') return 9.0;
      return 10.0;
    }
    return 12.0;
  }

  Alignment _getTokenAlignment(int index, int total) {
    if (total == 1) return Alignment.center;
    if (total == 2) {
      return index == 0 ? const Alignment(-0.45, 0) : const Alignment(0.45, 0);
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
    final fontSize = _getFontSize(label, hasAction);
    final int totalTokens = tokensInCell.length;
    final double tokenSize = totalTokens > 1 ? 16.0 : 20.0;

    // Lógica de área de toque inteligente:
    // Si solo hay una ficha seleccionable en toda la celda, permitimos tocar la celda completa.
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
            BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(1, 2)),
          ],
          border: Border.all(
            color: canTapCell ? Colors.orangeAccent.withOpacity(0.5) : Colors.black26,
            width: canTapCell ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                  color: hasAction ? Colors.black87 : Colors.black38,
                ),
              ),
            ),
            ...tokensInCell.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> data = entry.value;
              final Player player = data['player'];
              final Token token = data['token'];
              final bool isBlocked = controller.blockedPlayerIds.contains(player.id);

              final bool isSelectable = controller.engine.phase == GamePhase.choosing_token &&
                  controller.currentPlayer.id == player.id &&
                  controller.movableTokenIds.contains(token.id);

              return Align(
                alignment: _getTokenAlignment(index, totalTokens),
                child: Opacity(
                  opacity: isBlocked ? 0.4 : 1.0,
                  child: GestureDetector(
                    onTap: isSelectable ? () => controller.selectToken(token.id) : null,
                    behavior: HitTestBehavior.opaque, // Hace que el área transparente también sea clicable
                    child: Container(
                      width: 38, // Área de toque ampliada para el dedo
                      height: 38,
                      alignment: Alignment.center,
                      child: _TokenWidget(
                        asset: player.tokenAsset,
                        isSelectable: isSelectable,
                        size: tokenSize,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TokenWidget extends StatelessWidget {
  final String asset;
  final bool isSelectable;
  final double size;

  const _TokenWidget({
    required this.asset,
    required this.isSelectable,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget token = AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: 1.1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Image.asset(asset, width: size, height: size),
      ),
    );

    if (isSelectable) {
      return token
          .animate(onPlay: (c) => c.repeat())
          .moveY(begin: 0, end: -5, duration: 400.ms, curve: Curves.easeInOut)
          .then()
          .moveY(begin: -5, end: 0, duration: 400.ms, curve: Curves.easeInOut)
          .custom(
            builder: (context, value, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withValues(alpha: 0.5 * value),
                    blurRadius: 10 * value, 
                    spreadRadius: 2 * value
                  )
                ],
              ),
              child: child,
            ),
          );
    }

    return token;
  }
}
