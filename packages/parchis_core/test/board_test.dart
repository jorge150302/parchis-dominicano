import 'package:parchis_core/parchis_core.dart';
import 'package:test/test.dart';

void main() {
  test('bundled boards are valid and keep their sizes', () {
    expect(easyBoard.build().finalPosition, 49);
    expect(mediumBoard.build().finalPosition, 100);
    expect(hardBoard.build().finalPosition, 100);
    expect(quickBoard.build().finalPosition, 60);
    expect(boardById(defaultBoardId), mediumBoard);
    expect(boardById('nope'), isNull);
  });

  test('cells carry their actions', () {
    final board = mediumBoard.build();
    expect(board.getCell(13).action, const BoardAction.goToStart());
    expect(board.getCell(24).action, const BoardAction.moveTo(63));
    expect(board.getCell(14).hasAction, isFalse);
    expect(board.getCellSafe(0), isNull);
    expect(board.getCellSafe(101), isNull);
  });

  test('JSON round trip', () {
    for (final def in bundledBoards.values) {
      final back = BoardDefinition.fromJson(def.toJson());
      expect(back.id, def.id);
      expect(back.cellCount, def.cellCount);
      expect(back.actions, def.actions);
    }
  });

  test('unplayable boards are rejected', () {
    BoardDefinition make(Map<int, BoardAction> actions, {int cells = 30}) =>
        BoardDefinition(id: 'x', cellCount: cells, actions: actions);
    expect(() => make({}, cells: 5), throwsFormatException);
    expect(() => make({30: const BoardAction.rollAgain()}), throwsFormatException);
    expect(() => make({0: const BoardAction.rollAgain()}), throwsFormatException);
    expect(() => make({5: const BoardAction.moveTo(31)}), throwsFormatException);
    expect(() => make({5: const BoardAction.moveTo(5)}), throwsFormatException);
    expect(
      () => BoardDefinition.fromJson({
        'id': 'x',
        'cells': 30,
        'actions': {'3': {'type': 'teleport'}},
      }),
      throwsFormatException,
    );
  });
}
