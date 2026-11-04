// The rules themselves are tested in packages/parchis_core; these tests
// cover the server's layer on top: its dice, its models and the aliases
// rooms.dart relies on.
import 'dart:math';

import 'package:parchis_server/game_engine.dart';
import 'package:parchis_server/models/player.dart';
import 'package:test/test.dart';

GameEngine _engine({int players = 2, Random? random}) => GameEngine(
      board: mediumBoard.build(),
      players: [
        for (var i = 0; i < players; i++) Player(id: 'p$i', name: 'P$i'),
      ],
      random: random,
    );

void main() {
  test('rollDice returns 1..6 and records lastDiceValue', () {
    final engine = _engine(random: Random(42));
    for (var i = 0; i < 500; i++) {
      final v = engine.rollDice();
      expect(v, inInclusiveRange(1, 6));
      expect(engine.lastDiceValue, v);
    }
  });

  test('players get the official number of tokens', () {
    expect(
      Player(id: 'x', name: 'x').tokens,
      hasLength(RulesConfig.official.tokensPerPlayer),
    );
  });

  test('server players move, capture and finish through the shared engine',
      () {
    final engine = _engine();
    final me = engine.currentPlayer;
    final rival = engine.players[1];
    rival.tokens[0].position = 5;

    expect(engine.canMoveAnyToken(me, 5), isTrue);
    engine.roll(5);
    final landing = engine.move(me, me.tokens[0], 5);
    expect(landing.captures.single.owner, rival);
    expect(rival.tokens[0].position, 0);

    me.tokens[0].position = 99;
    me.tokens[1]
      ..isFinished = true
      ..position = -1;
    engine.roll(1);
    final done = engine.move(me, me.tokens[0], 1);
    expect(done.playerFinished, isTrue);
    expect(engine.finishedPlayers, [me, rival]);
    expect(engine.isOver, isTrue);
  });

  test('defaults to the medium board id', () {
    expect(_engine().boardId, mediumBoard.id);
  });
}
