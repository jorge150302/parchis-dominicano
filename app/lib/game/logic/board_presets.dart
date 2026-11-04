import '../models/board_action.dart';

final classicActionPositions = [
  2, 4, 6, 8
];

final classicActions = [
  BoardAction.rollAgain(),      // Pos 2: Repite tiro
  BoardAction.moveTo(7),        // Pos 4: Salto a la 7
  BoardAction.skipTurn(),       // Pos 6: Pierde turno
  BoardAction.goToStart(),      // Pos 8: A casa
];
