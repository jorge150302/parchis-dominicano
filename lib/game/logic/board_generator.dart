import '../models/board.dart';
import '../models/cell.dart';
import '../models/board_action.dart';

Board generateBoard(List<int> actionPositions, List<BoardAction> actions, {int totalCells = 10}) {
  List<Cell> cells = [];
  int actionIndex = 0;

  for (int i = 1; i <= totalCells; i++) {
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
    // Limpieza de índices por si hay acciones duplicadas o fuera de rango
    while (actionIndex < actionPositions.length && actionPositions[actionIndex] <= i) {
      actionIndex++;
    }
  }

  return Board(cells);
}
