// One group per rule in docs/reglas.md (R = shared rule, D/P = decision).
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
  P(this.id, List<int> positions)
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

/// A 30-cell track with actions only where a test puts them.
ParchisEngine<P> game(
  List<P> players, {
  Map<int, BoardAction> actions = const {},
  RulesConfig rules = RulesConfig.official,
}) =>
    ParchisEngine(
      board: BoardDefinition(id: 't', cellCount: 30, actions: actions).build(),
      players: players,
      rules: rules,
    );

void finish(T t) {
  t.isFinished = true;
  t.position = -1;
}

void main() {
  late P a, b, c;
  setUp(() {
    a = P('a', [0, 0]);
    b = P('b', [0, 0]);
    c = P('c', [0, 0]);
  });

  group('R2 leaving home', () {
    test('any number moves a token out', () {
      final g = game([a, b]);
      for (var d = 1; d <= 5; d++) {
        expect(g.roll(d).movable, hasLength(2), reason: 'dice $d');
        a.consecutiveSixes = 0;
      }
    });
  });

  group('R4 exact roll to finish', () {
    test('overshooting the last cell is not a move', () {
      a.tokens[0].position = 27;
      a.tokens[1].position = 27;
      final g = game([a, b]);
      expect(g.canMove(a, a.tokens[0], 3), isTrue);
      expect(g.canMove(a, a.tokens[0], 4), isFalse);
    });
  });

  group('R5/R6 rolls without a move', () {
    test('a lost roll passes the turn', () {
      a.tokens[0].position = 29;
      finish(a.tokens[1]);
      final out = game([a, b]).roll(3);
      expect(out.canMove, isFalse);
      expect(out.playAgain, isFalse);
    });

    test('a 6 rolls again even without a move', () {
      a.tokens[0].position = 29;
      finish(a.tokens[1]);
      final out = game([a, b]).roll(6);
      expect(out.canMove, isFalse);
      expect(out.playAgain, isTrue);
    });

    test('a 6 that moves rolls again', () {
      final g = game([a, b]);
      g.roll(6);
      expect(g.move(a, a.tokens[0], 6).playAgain, isTrue);
    });

    test('a plain move passes the turn', () {
      final g = game([a, b]);
      g.roll(4);
      expect(g.move(a, a.tokens[0], 4).playAgain, isFalse);
      expect(a.tokens[0].position, 4);
    });
  });

  group('R7 captures', () {
    test('each captured token goes home and grants one extra turn', () {
      b.tokens[0].position = 5;
      c.tokens[0].position = 5;
      final g = game([a, b, c]);
      g.roll(5);
      final out = g.move(a, a.tokens[0], 5);
      expect(out.captures.map((x) => x.owner.id), ['b', 'c']);
      expect(b.tokens[0].position, 0);
      expect(c.tokens[0].position, 0);
      expect(out.playAgain, isTrue);
      expect(a.extraTurns, 1, reason: 'two captures: one spent, one left');
    });

    test('tokens at home are never captured', () {
      final g = game([a, b]);
      g.roll(1);
      expect(g.move(a, a.tokens[0], 1).captures, isEmpty);
    });
  });

  group('R8 cell actions', () {
    test('go to start', () {
      final g = game([a, b], actions: {4: const BoardAction.goToStart()});
      g.roll(4);
      final out = g.move(a, a.tokens[0], 4);
      expect(out.sentHomeByCell, isTrue);
      expect(a.tokens[0].position, 0);
    });

    test('roll again', () {
      final g = game([a, b], actions: {4: const BoardAction.rollAgain()});
      g.roll(4);
      expect(g.move(a, a.tokens[0], 4).playAgain, isTrue);
    });

    test('skip turn: the player loses their next turn', () {
      final g = game([a, b], actions: {4: const BoardAction.skipTurn()});
      g.roll(4);
      g.move(a, a.tokens[0], 4);
      expect(g.nextTurn().skipped, isEmpty); // b plays
      expect(g.current, b);
      expect(g.nextTurn().skipped, [a]); // a is skipped, b again
      expect(g.current, b);
    });

    test('jumps forward and back, then captures where they land', () {
      b.tokens[0].position = 20;
      final g = game([a, b], actions: {
        4: const BoardAction.moveTo(20),
        6: const BoardAction.moveTo(2),
      });
      g.roll(4);
      final out = g.move(a, a.tokens[0], 4);
      expect(a.tokens[0].position, 20);
      expect(out.captures.single.owner, b);

      g.roll(6);
      g.move(a, a.tokens[1], 6);
      expect(a.tokens[1].position, 2);
    });
  });

  group('R9 a 6 on "skip turn"', () {
    test('cancels both the skip and the extra turn', () {
      final g = game([a, b], actions: {6: const BoardAction.skipTurn()});
      g.roll(6);
      final out = g.move(a, a.tokens[0], 6);
      expect(out.skipCancelledBySix, isTrue);
      expect(out.playAgain, isFalse);
      expect(a.skippedTurns, 0);
    });
  });

  group('R10 end of match', () {
    test('lastStanding ends when one player is left, ranked in order', () {
      a.tokens[0].position = 29;
      finish(a.tokens[1]);
      b.tokens[0].position = 29;
      finish(b.tokens[1]);
      final g = game([a, b, c]);
      g.roll(1);
      expect(g.move(a, a.tokens[0], 1).playerFinished, isTrue);
      expect(g.isOver, isFalse);
      g.nextTurn();
      g.roll(1);
      final out = g.move(b, b.tokens[0], 1);
      expect(out.gameOver, isTrue);
      expect(g.finishOrder, [a, b, c]);
      expect(g.nextTurn().gameOver, isTrue);
    });

    test('a finished player stops playing and is skipped', () {
      finish(a.tokens[0]);
      finish(a.tokens[1]);
      final g = game([a, b, c])..currentIndex = 2;
      g.nextTurn();
      expect(g.current, b);
    });
  });

  group('D1 three sixes', () {
    void threeSixes(ParchisEngine<P> g) {
      g.roll(6);
      g.roll(6);
    }

    setUp(() {
      a.tokens[0].position = 5;
      a.tokens[1].position = 9;
    });

    test('oneTokenHome (official): only the first token goes home', () {
      final g = game([a, b]);
      threeSixes(g);
      final out = g.roll(6);
      expect(out.threeSixes, isTrue);
      expect(out.sentHome.map((s) => (s.token, s.fromPosition)),
          [(a.tokens[0], 5)]);
      expect([a.tokens[0].position, a.tokens[1].position], [0, 9]);
      expect(a.extraTurns, 0);
      expect(out.playAgain, isFalse);
    });

    test('allTokensHome keeps pending skips', () {
      a.skippedTurns = 1;
      final g = game([a, b],
          rules: const RulesConfig(threeSixes: ThreeSixesPenalty.allTokensHome));
      threeSixes(g);
      expect(g.roll(6).sentHome, hasLength(2));
      expect(a.skippedTurns, 1);
    });

    test('loseTurn sends nothing home', () {
      final g = game([a, b],
          rules: const RulesConfig(threeSixes: ThreeSixesPenalty.loseTurn));
      threeSixes(g);
      final out = g.roll(6);
      expect(out.threeSixes, isTrue);
      expect(out.sentHome, isEmpty);
    });
  });

  group('D2 finish bonus', () {
    setUp(() => a.tokens[0].position = 27);

    test('a token reaching home grants an extra turn', () {
      final g = game([a, b]);
      g.roll(3);
      final out = g.move(a, a.tokens[0], 3);
      expect(out.tokenFinished, isTrue);
      expect(out.finishBonus, isTrue);
      expect(out.playAgain, isTrue);
    });

    test('not for the last token: that player is done', () {
      finish(a.tokens[1]);
      final g = game([a, b, c]);
      g.roll(3);
      final out = g.move(a, a.tokens[0], 3);
      expect(out.playerFinished, isTrue);
      expect(out.finishBonus, isFalse);
      expect(out.playAgain, isFalse);
    });

    test('also when a jump lands on home', () {
      a.tokens[0].position = 20;
      final g = game([a, b], actions: {22: const BoardAction.moveTo(30)});
      g.roll(2);
      final out = g.move(a, a.tokens[0], 2);
      expect(out.tokenFinished, isTrue);
      expect(out.finishBonus, isTrue);
      expect(a.tokens[0].position, -1);
    });

    test('off when finishBonus is false', () {
      final g = game([a, b], rules: const RulesConfig(finishBonus: false));
      g.roll(3);
      expect(g.move(a, a.tokens[0], 3).playAgain, isFalse);
    });
  });

  group('D3 bridges', () {
    setUp(() {
      b.tokens[0].position = 5;
      b.tokens[1].position = 5;
    });

    test('blocksEveryone: nobody crosses or lands, not even the owner', () {
      final g = game([a, b]);
      expect(g.canMove(a, a.tokens[0], 4), isTrue);
      expect(g.canMove(a, a.tokens[0], 5), isFalse);
      expect(g.canMove(a, a.tokens[0], 6), isFalse);
      b.tokens.add(T(2, 3));
      expect(g.canMove(b, b.tokens[2], 3), isFalse);
    });

    test('blocksOpponents: the owner passes its own bridge', () {
      final g = game([a, b],
          rules: const RulesConfig(bridges: BridgeRule.blocksOpponents));
      expect(g.canMove(a, a.tokens[0], 6), isFalse);
      b.tokens.add(T(2, 3));
      expect(g.canMove(b, b.tokens[2], 3), isTrue);
    });

    test('none: two tokens block nothing', () {
      final g = game([a, b], rules: const RulesConfig(bridges: BridgeRule.none));
      expect(g.canMove(a, a.tokens[0], 6), isTrue);
    });
  });

  group('D4 jump into a bridge', () {
    setUp(() {
      b.tokens[0].position = 20;
      b.tokens[1].position = 20;
    });

    test('jumpsRespectBridges (official): the token stays', () {
      final g = game([a, b], actions: {4: const BoardAction.moveTo(20)});
      g.roll(4);
      final out = g.move(a, a.tokens[0], 4);
      expect(out.jumpBlocked, isTrue);
      expect(a.tokens[0].position, 4);
    });

    test('otherwise the jump happens and captures both', () {
      final g = game([a, b],
          actions: {4: const BoardAction.moveTo(20)},
          rules: const RulesConfig(jumpsRespectBridges: false));
      g.roll(4);
      final out = g.move(a, a.tokens[0], 4);
      expect(a.tokens[0].position, 20);
      expect(out.captures, hasLength(2));
    });
  });

  group('D5 sixes per turn', () {
    test('sixesCountPerTurn (official): the count resets with the turn', () {
      final g = game([a, b]);
      a.consecutiveSixes = 2;
      g.nextTurn();
      expect(a.consecutiveSixes, 0);
    });

    test('otherwise the count carries over', () {
      final g = game([a, b], rules: const RulesConfig(sixesCountPerTurn: false));
      a.consecutiveSixes = 2;
      g.nextTurn();
      expect(a.consecutiveSixes, 2);
    });
  });

  group('P1 firstFinisher', () {
    test('ends on the first finish and ranks the rest by progress', () {
      a.tokens[0].position = 29;
      finish(a.tokens[1]);
      b.tokens[0].position = 3;
      c.tokens[0].position = 12;
      final g = game([a, b, c],
          rules: const RulesConfig(endCondition: EndCondition.firstFinisher));
      g.roll(1);
      final out = g.move(a, a.tokens[0], 1);
      expect(out.gameOver, isTrue);
      expect(out.playAgain, isFalse);
      expect(g.finishOrder, [a, c, b]);
    });
  });

  group('skips', () {
    test('when everyone owes a skip, one is cancelled for all silently', () {
      a.skippedTurns = 1;
      b.skippedTurns = 1;
      final g = game([a, b]);
      final adv = g.nextTurn();
      expect(adv.skipped, isEmpty);
      expect(g.current, b);
      expect([a.skippedTurns, b.skippedTurns], [0, 0]);
    });

    test('terminates when everyone owes several skips', () {
      a.skippedTurns = 3;
      b.skippedTurns = 2;
      final g = game([a, b]);
      g.nextTurn();
      expect(a.skippedTurns + b.skippedTurns, lessThan(5));
    });
  });
}
