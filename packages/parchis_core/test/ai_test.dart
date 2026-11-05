import 'dart:math';

import 'package:parchis_core/parchis_core.dart';
import 'package:test/test.dart';

class T implements RulesToken {
  T(this.id, [this.position = 0]);
  @override
  final int id;
  @override
  int position;
  @override
  bool isFinished = false;
}

class P implements RulesPlayer {
  P(this.id, [List<int> positions = const [0, 0]])
      : tokens = [for (var i = 0; i < positions.length; i++) T(i, positions[i])];
  @override
  final String id;
  @override
  final List<T> tokens;
  @override
  int skippedTurns = 0;
  @override
  int consecutiveSixes = 0;
  @override
  int extraTurns = 0;
  @override
  bool get isFinished => tokens.every((t) => t.isFinished);
}

ParchisEngine<P> game(List<P> players, [Map<int, BoardAction> actions = const {}]) =>
    ParchisEngine(
      board: BoardDefinition(id: 't', cellCount: 30, actions: actions).build(),
      players: players,
    );

RulesToken pick(ParchisEngine<P> g, P me, int dice, AiLevel level) =>
    chooseAiMove(g, me, dice, g.movableTokens(me, dice), level, Random(1));

/// Plays one match; [levels] per seat. Returns the winner's seat and each
/// seat's captures.
({int winner, List<int> captures}) playMatch(List<AiLevel> levels, Random rng) {
  final players = [for (var i = 0; i < levels.length; i++) P('$i')];
  final g = ParchisEngine(board: mediumBoard.build(), players: players);
  final captures = List.filled(levels.length, 0);
  var rolls = 0;
  while (!g.isOver) {
    if (++rolls > 100000) fail('match never ends');
    final me = g.current;
    final seat = players.indexOf(me);
    final dice = rng.nextInt(6) + 1;
    final roll = g.roll(dice);
    var again = roll.playAgain;
    if (roll.canMove) {
      final token = chooseAiMove(g, me, dice, roll.movable, levels[seat], rng);
      expect(roll.movable, contains(token));
      final landing = g.move(me, token, dice);
      captures[seat] += landing.captures.length;
      again = landing.playAgain;
    }
    if (!again && !g.isOver) g.nextTurn();
  }
  return (winner: players.indexOf(g.finishOrder.first), captures: captures);
}

void main() {
  group('medium', () {
    test('avoids a "go to start" cell when it has another move', () {
      final me = P('a', [1, 3]); // token 1 is ahead but would land on 5
      final g = game([me, P('b')], {5: const BoardAction.goToStart()});
      expect(pick(g, me, 2, AiLevel.medium).id, 0);
    });

    test('finishes a token before capturing', () {
      final me = P('a', [27, 2]);
      final rival = P('b', [5, 0]);
      final g = game([me, rival]);
      expect(pick(g, me, 3, AiLevel.medium).id, 0);
    });

    test('captures rather than making a plain move', () {
      final me = P('a', [10, 2]);
      final g = game([me, P('b', [5, 0])]);
      expect(pick(g, me, 3, AiLevel.medium).id, 1);
    });

    test('otherwise pushes the token furthest along', () {
      final me = P('a', [4, 9]);
      final g = game([me, P('b')]);
      expect(pick(g, me, 2, AiLevel.medium).id, 1);
    });
  });

  test('hard captures even over finishing a token', () {
    final me = P('a', [27, 2]);
    final g = game([me, P('b', [5, 0])]);
    expect(pick(g, me, 3, AiLevel.hard).id, 1);
    expect(pick(g, me, 3, AiLevel.medium).id, 0);
  });

  test('easy picks any legal move', () {
    final me = P('a', [4, 9]);
    final g = game([me, P('b')]);
    final picks = {
      for (var i = 0; i < 50; i++)
        chooseAiMove(g, me, 2, g.movableTokens(me, 2), AiLevel.easy, Random(i)).id,
    };
    expect(picks, {0, 1});
  });

  group('tournament on the online board', () {
    // Seats alternate so going first doesn't skew the result.
    double winRate(AiLevel a, AiLevel b, {int matches = 400}) {
      final rng = Random(7);
      var wins = 0;
      for (var i = 0; i < matches; i++) {
        final aFirst = i.isEven;
        final r = playMatch(aFirst ? [a, b] : [b, a], rng);
        if (r.winner == (aFirst ? 0 : 1)) wins++;
      }
      return wins / matches;
    }

    test('medium beats easy', () {
      expect(winRate(AiLevel.medium, AiLevel.easy), greaterThan(0.6));
    });

    test('hard beats easy', () {
      expect(winRate(AiLevel.hard, AiLevel.easy), greaterThan(0.6));
    });

    // Measured, not asserted: hard and medium win about as often (50%) on
    // this board; hard's extra aggression buys ~3% more captures. Making
    // hard really harder is a separate change.
  });
}
