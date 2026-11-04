// Match length by board, table size and end condition: plays many matches
// with the shared engine and reports rolls per match. Input for the target
// duration decision (docs/reglas.md, P4).
//
//   dart run tool/match_length.dart [matches] [seconds-per-roll]
// ignore_for_file: avoid_print

import 'dart:math';

import 'package:parchis_core/parchis_core.dart';

class _Token implements RulesToken {
  _Token(this.id);
  @override
  final int id;
  @override
  int position = 0;
  @override
  bool isFinished = false;
}

class _Player implements RulesPlayer {
  _Player(this.id, int tokens)
      : tokens = [for (var i = 0; i < tokens; i++) _Token(i)];
  @override
  final String id;
  @override
  final List<_Token> tokens;
  @override
  int skippedTurns = 0;
  @override
  int consecutiveSixes = 0;
  @override
  int extraTurns = 0;
  @override
  bool get isFinished => tokens.every((t) => t.isFinished);
}

/// Rolls until the match ends. Moves the most advanced movable token, like
/// the server's auto-play.
int playMatch(BoardDefinition board, int seats, RulesConfig rules, Random rng) {
  final engine = ParchisEngine(
    board: board.build(),
    players: [for (var i = 0; i < seats; i++) _Player('$i', rules.tokensPerPlayer)],
    rules: rules,
  );
  var rolls = 0;
  while (!engine.isOver) {
    if (++rolls > 100000) throw StateError('match never ends');
    final player = engine.current;
    final dice = rng.nextInt(6) + 1;
    final roll = engine.roll(dice);
    var again = roll.playAgain;
    if (roll.canMove) {
      final token = roll.movable.reduce((a, b) => a.position >= b.position ? a : b);
      again = engine.move(player, token, dice).playAgain;
    }
    if (!again && !engine.isOver) engine.nextTurn();
  }
  return rolls;
}

void main(List<String> args) {
  final matches = args.isNotEmpty ? int.parse(args[0]) : 500;
  final secondsPerRoll = args.length > 1 ? double.parse(args[1]) : 4.0;
  final rng = Random(1);

  print('Rolls per match ($matches matches each); minutes at '
      '${secondsPerRoll}s per roll.\n');
  print('| Board | Players | Ends when | Median rolls | 90% under | ~Minutes (median) |');
  print('|---|---|---|---|---|---|');
  for (final board in bundledBoards.values) {
    for (final seats in [2, 3, 4]) {
      for (final end in EndCondition.values) {
        final rules = RulesConfig(endCondition: end);
        final rolls = [for (var i = 0; i < matches; i++) playMatch(board, seats, rules, rng)]
          ..sort();
        final median = rolls[rolls.length ~/ 2];
        final p90 = rolls[(rolls.length * 0.9).floor()];
        final minutes = (median * secondsPerRoll / 60).toStringAsFixed(1);
        print('| ${board.id} | $seats | ${end.name} | $median | $p90 | $minutes |');
      }
    }
  }
}
