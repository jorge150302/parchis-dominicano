// lib/game/logic/board_generator.dart

import '../models/board.dart';
import '../models/cell.dart';
import '../models/board_action.dart';

Board generateBoard(List<int> actionPositions, List<BoardAction> actions) {
  List<Cell> cells = [];
  int totalCells = 10; // 🛠️ Reducido a 10 para pruebas rápidas de finalización
  int actionIndex = 0;

  for (int i = 1; i <= totalCells; i++) {
    // Solo agregamos acciones si están dentro del rango del tablero
    if (actionIndex < actionPositions.length && i == actionPositions[actionIndex]) {
      cells.add(Cell(
        number: i,
        type: CellType.action,
        action: actions[actionIndex],
      ));
      actionIndex++;
    } else {
      cells.add(Cell(number: i));
    }
    
    // Si la acción está fuera del tablero actual, avanzamos el índice para no procesarla
    while (actionIndex < actionPositions.length && actionPositions[actionIndex] <= i) {
      actionIndex++;
    }
  }

  return Board(cells);
}
