// lib/game/logic/board_actions_config.dart
import '../models/board_action.dart';

// ── EASY: 49 cells, no negative actions ──────────────────────────────────────
// Beginner-friendly: only rollAgain and forward jumps.
final easyActionPositions = [5, 10, 20, 28, 35, 42];

final easyActions = [
  BoardAction.rollAgain(),   // Pos  5
  BoardAction.moveTo(15),    // Pos 10: jump forward
  BoardAction.rollAgain(),   // Pos 20
  BoardAction.moveTo(32),    // Pos 28: jump forward
  BoardAction.rollAgain(),   // Pos 35
  BoardAction.moveTo(47),    // Pos 42: jump near finish
];

// ── MEDIUM: 100 cells, classic layout (baseline) ─────────────────────────────
final mediumActionPositions = [
  13, 15, 19, 24, 29, 37, 43, 49, 56, 66, 72, 76, 79, 83, 93, 97,
];

final mediumActions = [
  BoardAction.goToStart(),   // Pos 13
  BoardAction.rollAgain(),   // Pos 15
  BoardAction.skipTurn(),    // Pos 19
  BoardAction.moveTo(63),    // Pos 24: jump forward
  BoardAction.rollAgain(),   // Pos 29
  BoardAction.skipTurn(),    // Pos 37
  BoardAction.moveTo(25),    // Pos 43: go back
  BoardAction.moveTo(70),    // Pos 49: jump forward
  BoardAction.moveTo(18),    // Pos 56: go back
  BoardAction.skipTurn(),    // Pos 66
  BoardAction.rollAgain(),   // Pos 72
  BoardAction.moveTo(18),    // Pos 76: go back
  BoardAction.goToStart(),   // Pos 79
  BoardAction.moveTo(23),    // Pos 83: go back
  BoardAction.goToStart(),   // Pos 93
  BoardAction.moveTo(70),    // Pos 97: go back
];

// ── HARD: 100 cells, more negative actions at predictable positions ───────────
// Extra penalties placed at multiples of 6 (common dice landing zones)
// so players can learn and plan rather than feel cheated by randomness.
final hardActionPositions = [
  6, 12, 13, 15, 19, 24, 29, 30, 37, 43, 49,
  54, 56, 60, 66, 72, 76, 79, 83, 84, 90, 93, 97,
];

final hardActions = [
  BoardAction.skipTurn(),    // Pos  6  (new)
  BoardAction.goToStart(),   // Pos 12  (new)
  BoardAction.goToStart(),   // Pos 13
  BoardAction.rollAgain(),   // Pos 15
  BoardAction.skipTurn(),    // Pos 19
  BoardAction.moveTo(63),    // Pos 24: jump forward
  BoardAction.rollAgain(),   // Pos 29
  BoardAction.skipTurn(),    // Pos 30  (new)
  BoardAction.skipTurn(),    // Pos 37
  BoardAction.moveTo(25),    // Pos 43: go back
  BoardAction.moveTo(70),    // Pos 49: jump forward
  BoardAction.goToStart(),   // Pos 54  (new)
  BoardAction.moveTo(18),    // Pos 56: go back
  BoardAction.skipTurn(),    // Pos 60  (new)
  BoardAction.skipTurn(),    // Pos 66
  BoardAction.rollAgain(),   // Pos 72
  BoardAction.moveTo(18),    // Pos 76: go back
  BoardAction.goToStart(),   // Pos 79
  BoardAction.moveTo(23),    // Pos 83: go back
  BoardAction.goToStart(),   // Pos 84  (new)
  BoardAction.skipTurn(),    // Pos 90  (new)
  BoardAction.goToStart(),   // Pos 93
  BoardAction.moveTo(70),    // Pos 97: go back
];
