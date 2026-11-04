// Full offline matches through LocalGameController (the code path the
// offline game screen drives), with every seat on auto-play. Runs on fake
// time: the controller's animation delays elapse instantly.
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/config/language_provider.dart';
import 'package:frontend_parchis/game/logic/game_controller.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/game/models/player.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays a match to the end on fake time and returns the controller.
LocalGameController playMatch(BoardDefinition board, int seats) {
  late LocalGameController controller;
  fakeAsync((time) {
    controller = LocalGameController(
      engine: GameEngine(board: board.build(), players: []),
      vsAI: true,
    );
    controller.setPlayers([
      for (var i = 0; i < seats; i++)
        Player(id: '${i + 1}', name: 'P${i + 1}', index: i, tokenAsset: 't$i', isAI: i != 0)
          ..isAutoPlaying = i == 0,
    ]);
    controller.startTurn();

    final engine = controller.engine;
    // Hours of simulated play: far beyond any real match.
    for (var s = 0; s < 3 * 3600 && engine.phase != GamePhase.finished; s++) {
      time.elapse(const Duration(seconds: 1));
    }
    if (engine.phase != GamePhase.finished) {
      fail('${board.id}/$seats: stuck; phase ${engine.phase}, '
          'turn ${engine.currentPlayer.id}, locked ${controller.inputLocked}, '
          'rolling ${controller.rollingDice}, movable ${controller.movableTokenIds}, '
          'tokens ${engine.players.map((p) => p.tokens.map((t) => t.position).toList()).toList()}');
    }
  });
  return controller;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
      'game_speed': GameSpeed.fast.index,
      'auto_move_delay_ms': 0,
    });
    await PrefsService.init();
  });

  final keys = LanguageProvider.translations[Language.es]!.keys.toSet();

  for (final (board, seats) in [(easyBoard, 2), (mediumBoard, 2), (hardBoard, 3)]) {
    test('a ${board.id} match with $seats bots plays to the end', () {
      final controller = playMatch(board, seats);
      final engine = controller.engine;

      // Everyone is ranked once; the winner finished every token.
      expect(engine.finisherIds.toSet(), hasLength(seats));
      expect(engine.finisherIds, hasLength(seats));
      final winner = engine.players.firstWhere((p) => p.id == engine.finisherIds.first);
      expect(winner.tokens.every((t) => t.isFinished), isTrue);

      // No token ended on an impossible cell.
      for (final p in engine.players) {
        for (final t in p.tokens) {
          expect(t.isFinished ? t.position == -1 : t.position >= 0 && t.position < board.cellCount, isTrue,
              reason: '${p.id}/${t.id} at ${t.position}');
        }
      }

      // Every event the match produced can be shown.
      final unknown = engine.events.map((e) => e.messageKey).where((k) => !keys.contains(k)).toSet();
      expect(unknown, isEmpty);

      controller.dispose();
    });
  }

  test('a 6 with no legal move still rolls again', () {
    fakeAsync((time) {
      final controller = LocalGameController(
        engine: GameEngine(board: easyBoard.build(), players: []),
        random: _AlwaysSix(),
      );
      controller.setPlayers([
        // Both tokens 3 cells from home: a 6 overshoots.
        Player(id: '1', name: 'A', index: 0, tokenAsset: 'a')
          ..tokens[0].position = 46
          ..tokens[1].position = 46,
        Player(id: '2', name: 'B', index: 1, tokenAsset: 'b'),
      ]);
      controller.startTurn();
      controller.rollDice();
      time.elapse(const Duration(seconds: 10));
      expect(controller.engine.currentPlayer.id, '1');
      expect(controller.engine.phase, GamePhase.idle);
      controller.dispose();
    });
  });
}

class _AlwaysSix implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}
