import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/player.dart';
import '../models/cell.dart';
import '../models/board_action.dart';

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

          final playersInCell = widget.players
              .where((p) => p.position == cell.number)
              .toList();

          return _AnimatedCell(
            cell: cell,
            playersInCell: playersInCell,
          );
        },
      ),
    );
  }
}

class _AnimatedCell extends StatelessWidget {
  final Cell cell;
  final List<Player> playersInCell;

  const _AnimatedCell({
    required this.cell,
    required this.playersInCell,
  });

  String _getCellLabel(Cell cell) {
    if (cell.number == 0) return 'Inicio';
    if (cell.number == 100) return 'Fin';

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
          return 'Juegue otra vez'; // ✅ CAMBIO
      }
    }

    return cell.number.toString();
  }

  double _getFontSize(String label, bool hasAction) {
    if (hasAction) {
      // ✅ AJUSTE
      if (label == '1 turno sin jugar' || label == 'Juegue otra vez') return 7.5;
      if (label == 'INICIO') return 9.0;
      return 10.0; // "Al #"
    }
    return 12.0; // números
  }

  @override
  Widget build(BuildContext context) {
    final hasAction = cell.action != null;
    final label = _getCellLabel(cell);
    final fontSize = _getFontSize(label, hasAction);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: hasAction
            ? const LinearGradient(
                colors: [Color(0xffffd180), Color(0xffffb74d)])
            : const LinearGradient(
                colors: [Colors.white, Color(0xffeeeeee)],
              ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: Offset(1, 2),
          ),
        ],
        border: Border.all(color: Colors.black26),
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
              ),
            ),
          ),
          Center(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: playersInCell
                  .map(
                    (p) => AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: 1.15,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                        child: Image.asset(
                          p.tokenAsset,
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
