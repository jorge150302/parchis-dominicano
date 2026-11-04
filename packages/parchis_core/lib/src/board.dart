/// Boards as data: a track of numbered cells (1..[Board.finalPosition]),
/// some of which carry an action. Tokens start at 0 (home) and finish on
/// the last cell.
library;

enum BoardActionType { goToStart, moveTo, skipTurn, rollAgain }

class BoardAction {
  const BoardAction.goToStart()
      : type = BoardActionType.goToStart,
        targetNumber = null;

  const BoardAction.moveTo(int target)
      : type = BoardActionType.moveTo,
        targetNumber = target;

  const BoardAction.skipTurn()
      : type = BoardActionType.skipTurn,
        targetNumber = null;

  const BoardAction.rollAgain()
      : type = BoardActionType.rollAgain,
        targetNumber = null;

  final BoardActionType type;

  /// Destination cell, only for [BoardActionType.moveTo].
  final int? targetNumber;

  factory BoardAction.fromJson(Map<String, Object?> json) {
    switch (json['type']) {
      case 'goToStart':
        return const BoardAction.goToStart();
      case 'moveTo':
        final target = json['target'];
        if (target is! int) {
          throw const FormatException('moveTo needs an int "target"');
        }
        return BoardAction.moveTo(target);
      case 'skipTurn':
        return const BoardAction.skipTurn();
      case 'rollAgain':
        return const BoardAction.rollAgain();
    }
    throw FormatException('unknown action type ${json['type']}');
  }

  Map<String, Object?> toJson() => {
        'type': type.name,
        if (targetNumber != null) 'target': targetNumber,
      };

  @override
  bool operator ==(Object other) =>
      other is BoardAction &&
      other.type == type &&
      other.targetNumber == targetNumber;

  @override
  int get hashCode => Object.hash(type, targetNumber);
}

enum CellType { normal, action }

class Cell {
  const Cell({required this.number, this.action});

  final int number;
  final BoardAction? action;

  CellType get type => action == null ? CellType.normal : CellType.action;
  bool get hasAction => action != null;
}

class Board {
  Board(this.cells);

  final List<Cell> cells;

  /// The last cell; a token that reaches it is finished.
  int get finalPosition => cells.length;

  bool isValidPosition(int position) =>
      position >= 1 && position <= finalPosition;

  Cell getCell(int position) => cells[position - 1];

  Cell? getCellSafe(int position) =>
      isValidPosition(position) ? cells[position - 1] : null;

  bool isFinish(int position) => position >= finalPosition;
}

/// A board as stored in a catalog (bundled or remote): an id, a size and the
/// actions keyed by cell number.
class BoardDefinition {
  BoardDefinition({
    required this.id,
    required this.cellCount,
    required Map<int, BoardAction> actions,
  }) : actions = Map.unmodifiable(actions) {
    validate();
  }

  final String id;
  final int cellCount;
  final Map<int, BoardAction> actions;

  /// Throws [FormatException] for boards the engine cannot play: actions off
  /// the track, on the last cell, or jumps outside it.
  void validate() {
    if (cellCount < 10) {
      throw FormatException('board $id: needs at least 10 cells');
    }
    for (final MapEntry(key: cell, value: action) in actions.entries) {
      if (cell < 1 || cell >= cellCount) {
        throw FormatException('board $id: action on cell $cell is off-track');
      }
      final target = action.targetNumber;
      if (action.type == BoardActionType.moveTo &&
          (target == null || target < 1 || target > cellCount || target == cell)) {
        throw FormatException('board $id: bad jump $cell -> $target');
      }
    }
  }

  Board build() => Board([
        for (var i = 1; i <= cellCount; i++)
          Cell(number: i, action: actions[i]),
      ]);

  factory BoardDefinition.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final cells = json['cells'];
    final actions = json['actions'];
    if (id is! String || cells is! int || actions is! Map) {
      throw const FormatException('board needs "id", "cells" and "actions"');
    }
    return BoardDefinition(
      id: id,
      cellCount: cells,
      actions: {
        for (final MapEntry(:key, :value) in actions.entries)
          int.parse('$key'):
              BoardAction.fromJson(Map<String, Object?>.from(value as Map)),
      },
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'cells': cellCount,
        'actions': {
          for (final e in actions.entries) '${e.key}': e.value.toJson(),
        },
      };
}
