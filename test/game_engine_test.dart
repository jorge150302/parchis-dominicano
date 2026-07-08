import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/game/models/board.dart';
import 'package:frontend_parchis/game/models/cell.dart';
import 'package:frontend_parchis/game/models/player.dart';

void main() {
  late GameEngine engine;
  late Board board;
  late List<Player> players;

  setUp(() {
    // Setup a small board for testing
    List<Cell> cells = List.generate(20, (i) => Cell(number: i + 1));
    board = Board(cells);

    players = [
      Player(id: '1', name: 'Player 1', tokenAsset: 'red.png', index: 0, tokenCount: 4),
      Player(id: '2', name: 'Player 2', tokenAsset: 'blue.png', index: 1, tokenCount: 4),
    ];

    engine = GameEngine(board: board, players: players);
  });

  group('GameEngine Turn Tests', () {
    test('Initial current player is the first player', () {
      expect(engine.currentPlayerIndex, 0);
      expect(engine.currentPlayer.id, '1');
    });

    test('nextTurn advances to next player', () {
      engine.nextTurn();
      expect(engine.currentPlayerIndex, 1);
      expect(engine.currentPlayer.id, '2');
    });

    test('nextTurn wraps around', () {
      engine.nextTurn();
      engine.nextTurn();
      expect(engine.currentPlayerIndex, 0);
    });

    test('nextTurn skips finished players', () {
      // Finish player 2
      for (var t in players[1].tokens) {
        t.isFinished = true;
      }
      
      // Starting from player 1
      expect(engine.currentPlayerIndex, 0);
      engine.nextTurn();
      // Should remain player 1 if others are finished or phase becomes finished
      // Actually engine logic checks for active players count.
      expect(engine.phase, GamePhase.finished);
    });
  });

  group('GameEngine Movement Tests', () {
    test('canMoveToken validates boundaries', () {
      // Small board of 20 cells
      expect(engine.canMoveToken(players[0], 0, 5), true);
      expect(engine.canMoveToken(players[0], 0, 25), false); // Beyond final position
    });

    test('resolveCollisions captures other player tokens', () {
      players[0].tokens[0].position = 10;
      players[1].tokens[0].position = 10;

      final captures = engine.resolveCollisions(players[0], 0);

      expect(captures.length, 1);
      expect(captures[0].playerIndex, 1);
      expect(players[1].tokens[0].position, 0); // Reset to start
    });
  });
}
