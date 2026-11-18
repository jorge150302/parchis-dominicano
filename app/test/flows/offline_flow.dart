// The offline smoke flow, shared by the widget test (fake Firebase, fake
// time, runs anywhere) and the integration test (real app on Android
// emulators in CI): open the app, go to offline mode, start a 2-player
// match against the AI, roll the dice, and watch the match progress.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/game/logic/game_controller.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/game/widgets/board_widget.dart';
import 'package:provider/provider.dart';

/// Pumps until [finder] matches, failing after [timeout] of app time.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? reason,
}) async {
  const step = Duration(milliseconds: 200);
  for (var waited = Duration.zero; waited < timeout; waited += step) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(step);
  }
  fail(reason ?? 'not found after $timeout: $finder');
}

/// Runs the flow on an app that is already pumped and starting up.
Future<void> playOfflineAgainstAi(WidgetTester tester) async {
  // Splash, then the main menu.
  final offline = find.byKey(const Key('menu_offline'));
  await pumpUntilFound(tester, offline, reason: 'main menu never appeared');
  await tester.pump(const Duration(seconds: 1)); // entrance animations
  await tester.tap(offline);

  // Player selection: 2 players, against the AI (the default).
  final twoPlayers = find.byKey(const Key('player_count_2'));
  await pumpUntilFound(tester, twoPlayers, reason: 'player selection never appeared');
  await tester.pump(const Duration(seconds: 1));
  await tester.ensureVisible(twoPlayers);
  await tester.tap(twoPlayers);
  await tester.pump(const Duration(seconds: 1));
  final start = find.byKey(const Key('start_game'));
  await tester.ensureVisible(start);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(start);

  // The match.
  await pumpUntilFound(tester, find.byType(BoardWidget), reason: 'game board never appeared');
  final controller = Provider.of<GameController>(
    tester.element(find.byType(BoardWidget)),
    listen: false,
  );
  final engine = controller.engine;
  await pumpUntilFound(tester, find.byKey(const Key('roll_dice_1')), reason: 'no dice for the player');
  await tester.pump(const Duration(seconds: 1));
  expect(engine.currentPlayer.id, '1', reason: 'the human starts');

  // The human rolls through the UI…
  await tester.tap(find.byKey(const Key('roll_dice_1')));
  final rolled = DateTime.now();
  for (var i = 0; i < 50 && !controller.rollingDice && engine.phase == GamePhase.idle; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(engine.phase != GamePhase.idle || controller.rollingDice, isTrue,
      reason: 'tapping the dice did not roll (${DateTime.now().difference(rolled)})');

  // …then hands over to auto-play, and the AI must take its turns too.
  controller.toggleAutoPlay(true);
  var aiTurns = 0;
  var last = engine.currentPlayer.id;
  for (var i = 0; i < 600 && aiTurns < 3; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (engine.currentPlayer.id != last) {
      last = engine.currentPlayer.id;
      if (last == '2') aiTurns++;
    }
  }
  expect(aiTurns, 3, reason: 'the match did not keep going');
  final moved = engine.players.expand((p) => p.tokens).where((t) => t.position != 0);
  expect(moved, isNotEmpty, reason: 'no token ever left home');
}
