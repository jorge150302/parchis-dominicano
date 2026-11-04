// Decision P4 (docs/reglas.md): a 4-player online match (medium board,
// official rules) lasts 30 to 60 minutes. Fails when a rule or board change
// moves the typical match out of that range.
import 'dart:math';

import 'package:parchis_core/parchis_core.dart';
import 'package:test/test.dart';

import '../tool/match_length.dart' show playMatch;

/// Real time per roll online: dice and step animations plus the player's
/// decision. Measured from the server's delays (300 ms + 200 ms per step +
/// 300 ms) and the app's dice animation, rounded up for human play.
const secondsPerRoll = 4;

void main() {
  test('a 4-player online match takes 30 to 60 minutes (median)', () {
    final rng = Random(42);
    final board = boardById(defaultBoardId)!;
    final rolls = [
      for (var i = 0; i < 300; i++)
        playMatch(board, 4, RulesConfig.official, rng),
    ]..sort();
    final minutes = rolls[rolls.length ~/ 2] * secondsPerRoll / 60;
    expect(minutes, inInclusiveRange(30, 60),
        reason: 'median ${minutes.toStringAsFixed(1)} min');
  });
}
