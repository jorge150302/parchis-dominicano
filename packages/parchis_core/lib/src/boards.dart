import 'board.dart';

/// Bundled boards. The ids are stable: rooms, saved games and the store
/// refer to boards by id.
final easyBoard = BoardDefinition(
  id: 'easy',
  cellCount: 49,
  // Beginner-friendly: only rollAgain and forward jumps.
  actions: const {
    5: BoardAction.rollAgain(),
    10: BoardAction.moveTo(15),
    20: BoardAction.rollAgain(),
    28: BoardAction.moveTo(32),
    35: BoardAction.rollAgain(),
    42: BoardAction.moveTo(47),
  },
);

/// The classic layout, and the board online rooms use by default.
final mediumBoard = BoardDefinition(
  id: 'medium',
  cellCount: 100,
  actions: const {
    13: BoardAction.goToStart(),
    15: BoardAction.rollAgain(),
    19: BoardAction.skipTurn(),
    24: BoardAction.moveTo(63),
    29: BoardAction.rollAgain(),
    37: BoardAction.skipTurn(),
    43: BoardAction.moveTo(25),
    49: BoardAction.moveTo(70),
    58: BoardAction.moveTo(25),
    66: BoardAction.skipTurn(),
    72: BoardAction.rollAgain(),
    78: BoardAction.moveTo(45),
    81: BoardAction.moveTo(50),
    83: BoardAction.moveTo(55),
    93: BoardAction.moveTo(65),
    97: BoardAction.moveTo(90),
  },
);

/// More penalties, several on multiples of 6 so players can learn them.
final hardBoard = BoardDefinition(
  id: 'hard',
  cellCount: 100,
  actions: const {
    6: BoardAction.skipTurn(),
    12: BoardAction.goToStart(),
    13: BoardAction.goToStart(),
    15: BoardAction.rollAgain(),
    19: BoardAction.skipTurn(),
    24: BoardAction.moveTo(63),
    29: BoardAction.rollAgain(),
    30: BoardAction.skipTurn(),
    37: BoardAction.skipTurn(),
    43: BoardAction.moveTo(25),
    49: BoardAction.moveTo(70),
    54: BoardAction.goToStart(),
    56: BoardAction.moveTo(18),
    60: BoardAction.skipTurn(),
    66: BoardAction.skipTurn(),
    72: BoardAction.rollAgain(),
    76: BoardAction.moveTo(18),
    79: BoardAction.goToStart(),
    83: BoardAction.moveTo(23),
    84: BoardAction.goToStart(),
    90: BoardAction.skipTurn(),
    93: BoardAction.goToStart(),
    97: BoardAction.moveTo(70),
  },
);

/// Short matches (Phase 4.3): 60 cells, mild setbacks. About 15 minutes
/// for four players (tool/match_length.dart), against about 50 on medium.
final quickBoard = BoardDefinition(
  id: 'quick',
  cellCount: 60,
  actions: const {
    8: BoardAction.rollAgain(),
    12: BoardAction.moveTo(20),
    17: BoardAction.skipTurn(),
    25: BoardAction.rollAgain(),
    30: BoardAction.moveTo(38),
    35: BoardAction.goToStart(),
    42: BoardAction.rollAgain(),
    46: BoardAction.moveTo(53),
    50: BoardAction.moveTo(44),
    56: BoardAction.moveTo(51),
  },
);

final defaultBoardId = mediumBoard.id;

final bundledBoards = {
  for (final b in [easyBoard, mediumBoard, hardBoard, quickBoard]) b.id: b,
};

/// The bundled board with [id], or null.
BoardDefinition? boardById(String? id) => bundledBoards[id];
