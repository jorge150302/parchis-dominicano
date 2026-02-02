import 'package:flutter/material.dart';

import '../models/board.dart';
import '../models/player.dart';
import '../models/cell.dart';
import '../models/board_action.dart';

class BoardWidget extends StatelessWidget {
  final Board board;
  final List<Player> players;

  const BoardWidget({
    super.key,
    required this.board,
    required this.players,
  });

  static const int columns = 10;

  @override
  Widget build(BuildContext context) {
    /// 🔥 1) ORDEN INVERTIDO
    /// Inicio abajo izquierda → Fin arriba derecha
    final cells = board.cells.reversed.toList();

    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cells.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
        ),
        itemBuilder: (_, visualIndex) {
          /// 🔥 2) ZIGZAG
          final row = visualIndex ~/ columns;
          final col = visualIndex % columns;

          final zigzagCol = row.isOdd ? (columns - 1 - col) : col;
          final realIndex = row * columns + zigzagCol;

          final cell = cells[realIndex];

          final playersInCell =
          players.where((p) => p.position == cell.number).toList();

          return _buildCell(cell, playersInCell);
        },
      ),
    );
  }

  // ===================================================
  // 🔥 TEXTO DE CELDA (Número o Acción)
  // ===================================================
  String _getCellLabel(Cell cell) {
    /// Inicio / Fin
    if (cell.number == 0) return 'Inicio';
    if (cell.number == 100) return 'Fin';

    /// Si tiene acción → mostrar nombre de acción
    final action = cell.action;

    if (action != null) {
      switch (action.type) {
        case BoardActionType.goToStart:
          return 'INICIO';

        case BoardActionType.moveTo:
          return 'SALTA ${action.targetNumber ?? ''}';

        case BoardActionType.skipTurn:
          return 'PIERDE TURNO';

        case BoardActionType.rollAgain:
          return 'TIRA OTRA';
      }
    }

    /// normal → número
    return cell.number.toString();
  }

  // ===================================================
  // CELDA
  // ===================================================
  Widget _buildCell(Cell cell, List<Player> playersInCell) {
    final label = _getCellLabel(cell);

    final bool hasAction = cell.action != null;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: hasAction
            ? Colors.orange.shade200 // 🔥 resalta acciones
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black26),
      ),
      child: Stack(
        children: [
          /// 🔥 label (acción o número)
          Positioned(
            top: 2,
            left: 4,
            right: 2,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: hasAction ? 8 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          /// 🔥 fichas PNG dinámicas
          Center(
            child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: playersInCell
                  .map(
                    (p) => Image.asset(
                  p.tokenAsset,
                  width: 18,
                  height: 18,
                  fit: BoxFit.contain,
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
