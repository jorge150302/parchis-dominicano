// The rules are tested in packages/parchis_core. These tests cover the
// app's layer: the event feed, turn hand-off, finishers and saved games.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/game/models/player.dart';

void main() {
  late List<Player> players;

  GameEngine engineWith([Map<int, BoardAction> actions = const {}]) => GameEngine(
        board: BoardDefinition(id: 't', cellCount: 20, actions: actions).build(),
        players: players,
      );

  List<String> keys(GameEngine e) => e.events.map((ev) => ev.messageKey).toList();

  /// Steps [player]'s token [dice] cells and lands it, like the controller.
  LandingOutcome<Player> move(GameEngine e, Player player, int tokenId, int dice) {
    for (var i = 0; i < dice; i++) {
      if (e.stepToken(player, tokenId)) break;
    }
    return e.landToken(player, tokenId, dice);
  }

  setUp(() {
    players = [
      Player(id: '1', name: 'Ana', tokenAsset: 'red.png', index: 0),
      Player(id: '2', name: 'Beto', tokenAsset: 'blue.png', index: 1),
    ];
  });

  test('players get the official number of tokens', () {
    expect(players[0].tokens, hasLength(RulesConfig.official.tokensPerPlayer));
  });

  test('a plain move passes the turn', () {
    final engine = engineWith();
    engine.rollDice(4);
    final landing = move(engine, players[0], 0, 4);
    expect(players[0].tokens[0].position, 4);
    engine.endAction(playAgain: landing.playAgain);
    expect(engine.currentPlayer.id, '2');
    expect(engine.phase, GamePhase.idle);
  });

  test('cell actions and captures are reported in the event feed', () {
    final engine = engineWith({3: const BoardAction.rollAgain()});
    players[1].tokens[0].position = 3;
    engine.rollDice(3);
    final landing = move(engine, players[0], 0, 3);
    expect(keys(engine), ['roll_again', 'captured_player']);
    expect(landing.captures.single.owner.index, 1);

    // A specific bonus already explains the extra turn.
    engine.endAction(playAgain: landing.playAgain);
    expect(keys(engine), isNot(contains('extra_turn')));
    expect(engine.currentPlayer.id, '1');
  });

  test('a 6 without a specific bonus announces the extra turn', () {
    final engine = engineWith();
    engine.rollDice(6);
    final landing = move(engine, players[0], 0, 6);
    engine.endAction(playAgain: landing.playAgain);
    expect(keys(engine), ['extra_turn']);
    expect(engine.currentPlayer.id, '1');
  });

  test('three sixes are reported and pass the turn', () {
    final engine = engineWith();
    players[0].tokens[0].position = 5;
    engine.rollDice(6);
    engine.rollDice(6);
    final roll = engine.rollDice(6);
    expect(roll.threeSixes, isTrue);
    expect(keys(engine), ['penalty_three_sixes']);
    engine.endAction(playAgain: false);
    expect(engine.currentPlayer.id, '2');
  });

  test('skipped players are announced', () {
    final engine = engineWith();
    players[1].skippedTurns = 1;
    engine.endAction(playAgain: false);
    expect(keys(engine), ['skip_turn_msg']);
    expect(engine.currentPlayer.id, '1');
  });

  test('the last finish ends the match and fills finisherIds', () {
    final engine = engineWith();
    players[0].tokens[1]
      ..isFinished = true
      ..position = -1;
    players[0].tokens[0].position = 19;
    engine.rollDice(1);
    final landing = move(engine, players[0], 0, 1);
    engine.endAction(playAgain: landing.playAgain);
    expect(engine.phase, GamePhase.finished);
    expect(engine.finisherIds, ['1', '2']);
  });

  test('saved games restore the turn, phase and finishers', () {
    final engine = engineWith();
    players[0].tokens[0].position = 7;
    engine
      ..currentIndex = 1
      ..phase = GamePhase.choosing_token
      ..finisherIds.add('1');
    final restored = GameEngine.fromSavedState(engine.toJson(), engine.board);
    expect(restored.currentPlayer.id, '2');
    expect(restored.phase, GamePhase.choosing_token);
    expect(restored.finisherIds, ['1']);
    expect(restored.finishOrder.single.id, '1');
    expect(restored.players[0].tokens[0].position, 7);
  });

  test('online helpers: movable ids and current player by id', () {
    final engine = engineWith();
    expect(engine.getMovableTokenIds(5), [0, 1]);
    expect(engine.canMoveToken(players[0], 0, 25), isFalse);
    engine.setCurrentPlayerById('2');
    expect(engine.currentPlayer.id, '2');
  });
}
