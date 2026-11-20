// The first-run tutorial played through the UI like a new player: accept
// the invitation, read each card, roll and move when asked. Each
// explanation is checked against the board it describes, so a rules or
// board change that breaks the script fails here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/game/logic/game_controller.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/game/tutorial/tutorial_director.dart';
import 'package:frontend_parchis/game/tutorial/tutorial_overlay.dart';
import 'package:frontend_parchis/game/tutorial/tutorial_script.dart';
import 'package:frontend_parchis/game/widgets/board_widget.dart';
import 'package:frontend_parchis/main.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/sync_queue_service.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:provider/provider.dart';

import 'flows/offline_flow.dart';
import 'helpers/screen_harness.dart';

TutorialDirector _director(WidgetTester tester) =>
    tester.widget<TutorialOverlay>(find.byType(TutorialOverlay)).director;

List<int> _cells(GameEngine e, String playerId) => [
  for (final t in e.players.firstWhere((p) => p.id == playerId).tokens)
    t.isFinished ? -1 : t.position,
];

/// What the board must show while each explanation is on screen.
void _checkBoard(String textKey, GameEngine e) {
  final you = _cells(e, tutorialYou), rival = _cells(e, tutorialRival);
  final turn = e.currentPlayer.id;
  switch (textKey) {
    case 'tut_capture_done':
      expect(
        [you, rival, turn],
        [
          [23, 0],
          [0, 0],
          tutorialYou,
        ],
        reason: 'captured, with the extra roll',
      );
    case 'tut_cell_extra':
      expect(
        [you[0], turn],
        [15, tutorialYou],
        reason: 'on "extra turn", still playing',
      );
    case 'tut_bridge_done':
      expect(you, [30, 30], reason: 'a bridge on 30');
    case 'tut_bridge_blocked':
      expect(
        [rival, turn],
        [
          [28, 27],
          tutorialYou,
        ],
        reason: 'blue could not cross the bridge',
      );
    case 'tut_sixes_done':
      expect(
        [rival, turn],
        [
          [0, 0],
          tutorialYou,
        ],
        reason: 'the third 6 sent blue home',
      );
    case 'tut_exact_over':
      expect(
        [you, turn],
        [
          [98, 99],
          tutorialYou,
        ],
        reason: 'a 6 overshoots, and rolls again',
      );
    case 'tut_finish_bonus':
      expect(
        [you, turn],
        [
          [-1, 99],
          tutorialYou,
        ],
        reason: 'one token home, bonus roll',
      );
  }
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150 && finder.evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsNothing);
}

/// Leaves the match so no game timers outlive the test.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

Future<void> _openTutorial(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MyApp(auth: signedOutAuth()));
  final accept = find.text('Sí, aprender ahora');
  await pumpUntilFound(
    tester,
    accept,
    reason: 'no tutorial invitation for a new player',
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(accept);
  await pumpUntilFound(
    tester,
    find.byType(TutorialOverlay),
    reason: 'the tutorial did not open',
  );
  await tester.pump(const Duration(seconds: 1));
}

/// Plays the tutorial to its last card; returns the read cards in order.
Future<List<String>> _playThrough(WidgetTester tester) async {
  final reads = <String>[];
  for (var i = 0; i < 3000; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final d = _director(tester);
    if (d.isDone) {
      // The last card's entrance: both buttons must end up tappable.
      for (final button in ['tutorial_menu', 'tutorial_play_ai']) {
        await pumpUntilFound(
          tester,
          find.byKey(Key(button)).hitTestable(),
          timeout: const Duration(seconds: 5),
          reason: '$button never became tappable',
        );
      }
      return reads;
    }
    final c = d.controller;
    if (d.waitingForTap) {
      final key = d.step!.textKey;
      _checkBoard(key, c.engine);
      reads.add(key);
      final screen =
          Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        screen.contains(
          tester.getCenter(find.byKey(const Key('tutorial_next'))),
        ),
        isTrue,
        reason: '"Next" is off screen on "$key"',
      );
      await tester.tap(find.byKey(const Key('tutorial_next')));
    } else if (d.waitingForUser) {
      if (c.engine.phase == GamePhase.idle &&
          !c.rollingDice &&
          !c.inputLocked) {
        await tester.tap(find.byKey(const Key('roll_dice_$tutorialYou')));
      } else if (c.engine.phase == GamePhase.choosing_token) {
        await tester.tap(
          find
              .byWidgetPredicate((w) => w is TokenWidget && w.isSelectable)
              .first,
        );
      }
    }
  }
  fail(
    'the tutorial never reached its end (stuck on ${_director(tester).step?.textKey})',
  );
}

void main() {
  setUp(() async {
    muteAudioPlugins();
    await usePrefs({'is_first_time': true});
  });
  tearDown(() => socketService.disconnect());

  for (final MapEntry(key: device, value: size) in {
    'phone 412x915': const Size(412, 915),
    'small phone 320x568': const Size(320, 568),
  }.entries) {
    testWidgets('a new player completes the tutorial on a $device', (
      tester,
    ) async {
      await _openTutorial(tester, size);
      final reads = await _playThrough(tester);

      expect(reads, [
        for (final s in tutorialSteps)
          if (s.kind == TutorialStepKind.read) s.textKey,
      ], reason: 'every explanation was shown, in order');
      final engine = _director(tester).controller.engine;
      expect(engine.phase, GamePhase.finished);
      expect(
        engine.finisherIds.first,
        tutorialYou,
        reason: 'the learner wins the last scene',
      );

      // Ends on its own card, not the match results, with the reward.
      expect(find.byKey(const Key('tutorial_finish')), findsOneWidget);
      expect(find.byKey(const Key('tutorial_reward')), findsOneWidget);
      expect(PrefsService.totalXp, SyncQueueService.tutorialRewardXp);
      await tester.tap(find.byKey(const Key('tutorial_menu')));
      await pumpUntilFound(
        tester,
        find.byKey(const Key('menu_offline')),
        reason: 'did not return to the menu',
      );
    });
  }

  testWidgets(
    'every step shows its progress and the scenes count up to the last',
    (tester) async {
      await _openTutorial(tester, const Size(412, 915));
      expect(find.text('Paso 1 de 8'), findsOneWidget);
      expect(_director(tester).sceneCount, 8);
      await _leave(tester);
    },
  );

  testWidgets('a read card never lets the dice roll', (tester) async {
    await _openTutorial(tester, const Size(412, 915));
    final d = _director(tester);
    final c = d.controller;
    expect(d.waitingForTap, isTrue, reason: 'the first card is a read');
    final actions = c.turnSerial;

    await c.rollDice(); // even a direct call is refused
    expect(c.rollingDice, isFalse);

    // A tap on the dice only turns the card.
    await tester.tap(
      find.byKey(const Key('roll_dice_$tutorialYou')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(d.stepIndex, 1, reason: 'a tap anywhere turns a read card');
    expect(c.turnSerial, actions, reason: 'no roll happened');
    expect(c.engine.phase, GamePhase.idle);
    await _leave(tester);
  });

  testWidgets('a scene only lets the learner move the token it is about', (
    tester,
  ) async {
    await _openTutorial(tester, const Size(412, 915));
    final d = _director(tester);
    // Read and act until the capture move, where only the token on 20 may go.
    for (var i = 0; i < 600; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (d.textKey == 'tut_capture_move') break;
      final c = d.controller;
      if (d.waitingForTap) {
        await tester.tap(find.byKey(const Key('tutorial_next')));
      } else if (d.waitingForUser &&
          c.engine.phase == GamePhase.idle &&
          !c.inputLocked &&
          !c.rollingDice) {
        await tester.tap(find.byKey(const Key('roll_dice_$tutorialYou')));
      } else if (d.waitingForUser &&
          c.engine.phase == GamePhase.choosing_token) {
        await tester.tap(
          find
              .byWidgetPredicate((w) => w is TokenWidget && w.isSelectable)
              .first,
        );
      }
    }
    expect(d.textKey, 'tut_capture_move');
    expect(
      d.controller.movableTokenIds,
      [0],
      reason: 'the token at home could also leave with a 3',
    );
    await _leave(tester);
  });

  testWidgets('skip leaves the tutorial for the menu', (tester) async {
    await _openTutorial(tester, const Size(412, 915));
    await tester.tap(find.byKey(const Key('tutorial_skip')));
    await _pumpUntilGone(tester, find.byType(TutorialOverlay));
    expect(PrefsService.totalXp, 0, reason: 'skipping earns nothing');
    expect(PrefsService.pendingSyncReceipts, isEmpty);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('menu_offline')),
      reason: 'skip did not reach the menu',
    );
    expect(find.byType(TutorialOverlay), findsNothing);
  });

  testWidgets('finishing it again gives no second reward', (tester) async {
    await usePrefs({
      'is_first_time': true,
      'tutorial_xp_claimed_by': ['guest'],
    });
    await _openTutorial(tester, const Size(412, 915));
    await _playThrough(tester);
    expect(find.byKey(const Key('tutorial_finish')), findsOneWidget);
    expect(find.byKey(const Key('tutorial_reward')), findsNothing);
    expect(PrefsService.totalXp, 0);
    expect(PrefsService.pendingSyncReceipts, isEmpty);
    await _leave(tester);
  });

  testWidgets('the last card starts a real match against the AI', (
    tester,
  ) async {
    await _openTutorial(tester, const Size(412, 915));
    await _playThrough(tester);
    await tester.tap(find.byKey(const Key('tutorial_play_ai')));
    await _pumpUntilGone(tester, find.byType(TutorialOverlay));
    await tester.pump(const Duration(seconds: 2));
    await pumpUntilFound(tester, find.byType(BoardWidget));
    expect(
      find.byType(TutorialOverlay),
      findsNothing,
      reason: 'a normal match, no tutorial',
    );
    final controller = Provider.of<GameController>(
      tester.element(find.byType(BoardWidget)),
      listen: false,
    );
    expect(
      controller,
      isA<LocalGameController>().having((c) => c.vsAI, 'vsAI', isTrue),
    );
    expect(
      controller.engine.players
          .map((p) => p.tokens.map((t) => t.position))
          .expand((x) => x),
      everyElement(0),
      reason: 'a fresh board',
    );

    await _leave(tester);
  });
}
