// lib/game/logic/board_actions_config.dart
import '../models/board_action.dart';

// Lista de acciones para el tablero
final classicActionPositions = [
  13, 15, 19, 24, 29, 37, 43, 49, 56, 66, 72, 76, 79, 83
];

final classicActions = [
  BoardAction.goToStart(),
  BoardAction.rollAgain(),
  BoardAction.skipTurn(),
  BoardAction.moveTo(63),
  BoardAction.rollAgain(),
  BoardAction.skipTurn(),
  BoardAction.moveTo(24),
  BoardAction.moveTo(70),
  BoardAction.moveTo(18),
  BoardAction.skipTurn(),
  BoardAction.rollAgain(),
  BoardAction.moveTo(18),
  BoardAction.goToStart(),
  BoardAction.moveTo(70),
];
