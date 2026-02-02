// lib/game/logic/board_presets.dart

import '../models/board_action.dart';

// Posiciones en las que habrá acciones (después del número indicado)
final classicActionPositions = [
  13, 15, 19, 24, 29, 37, 43, 49, 56, 66, 72, 76, 79, 83
];

final classicActions = [
  BoardAction.goToStart(),    // después del 12
  BoardAction.rollAgain(),    // después del 14
  BoardAction.skipTurn(),     // después del 18
  BoardAction.moveTo(63),     // después del 23
  BoardAction.rollAgain(),    // después del 28
  BoardAction.skipTurn(),     // después del 36
  BoardAction.moveTo(24),     // después del 42
  BoardAction.moveTo(70),     // después del 48
  BoardAction.moveTo(18),     // después del 55
  BoardAction.skipTurn(),     // después del 65
  BoardAction.rollAgain(),    // después del 71
  BoardAction.moveTo(18),     // después del 75
  BoardAction.goToStart(),    // después del 78
  BoardAction.moveTo(70),     // después del 82
];
