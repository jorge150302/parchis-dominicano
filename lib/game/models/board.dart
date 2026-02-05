// lib/game/models/board.dart

import 'cell.dart';

class Board {
  final List<Cell> cells;

  Board(this.cells);

  /// =====================================================
  /// 📍 POSICIONES
  /// =====================================================

  /// última casilla real
  int get finalPosition => cells.length;

  /// valida límites
  bool isValidPosition(int position) {
    return position >= 1 && position <= finalPosition;
  }

  /// segura (nunca rompe)
  Cell? getCellSafe(int position) {
    if (!isValidPosition(position)) return null;
    return cells[position - 1];
  }

  /// usada por engine
  Cell getCell(int position) {
    return cells[position - 1];
  }

  /// helpers útiles
  bool isFinish(int position) => position >= finalPosition;
}
