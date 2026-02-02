// lib/game/models/board.dart

import 'cell.dart';

class Board {
  final List<Cell> cells;

  Board(this.cells);

  int get finalPosition => cells.length;

  Cell getCell(int position) => cells[position - 1];
}
