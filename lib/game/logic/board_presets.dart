import '../models/board_action.dart';

final classicActionPositions = [
  3, 13, 15, 19, 24, 29, 37, 43, 49, 56, 66, 72, 76, 79, 83, 93, 97
];

final classicActions = [
  BoardAction.skipTurn(),       // 3
  BoardAction.goToStart(),      // 13
  BoardAction.rollAgain(),      // 15
  BoardAction.skipTurn(),       // 19
  BoardAction.moveTo(63),       // 24
  BoardAction.rollAgain(),      // 29
  BoardAction.skipTurn(),       // 37
  BoardAction.moveTo(25),       // 43 (era 24)
  BoardAction.moveTo(70),       // 49
  BoardAction.moveTo(18),       // 56
  BoardAction.skipTurn(),       // 66
  BoardAction.rollAgain(),      // 72
  BoardAction.moveTo(18),       // 76
  BoardAction.goToStart(),      // 79
  BoardAction.moveTo(23),       // 83 (era 70)
  BoardAction.goToStart(),      // 93 (nuevo)
  BoardAction.moveTo(70),       // 97 (nuevo)
];
