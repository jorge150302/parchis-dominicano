// End-to-end: the app's real SocketService and NetworkGameController play a
// short online match against a running parchis_server, with a raw WebSocket
// bot in the second seat. Catches protocol drift between client and server.
//
// Needs a server started with PARCHIS_DEV_AUTH_BYPASS=true and
// PARCHIS_ALLOW_TEST_MODE=true; skipped unless PARCHIS_E2E_URL is set:
//   PARCHIS_E2E_URL=ws://localhost:8080/ws flutter test test/e2e
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/game/logic/game_controller.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _url = Platform.environment['PARCHIS_E2E_URL'];

/// Second player: joins a room and plays its turns like the stress-test bots.
class _Bot {
  _Bot(String url) : _channel = WebSocketChannel.connect(Uri.parse(url));

  final WebSocketChannel _channel;
  final id = 'e2e-bot-${DateTime.now().microsecondsSinceEpoch}';
  final finished = Completer<void>();

  void _send(String event, [Map<String, dynamic>? data]) =>
      _channel.sink.add(jsonEncode({'event': event, 'clientId': id, 'data': data}));

  Future<void> join(String roomCode) async {
    await _channel.ready;
    _channel.stream.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['event'] != 'game_state') return;
      final s = msg['data'] as Map<String, dynamic>;
      if (s['phase'] == 'finished' && !finished.isCompleted) finished.complete();
      if (s['currentPlayerId'] != id) return;
      if (s['phase'] == 'rolling') {
        _send('roll_dice');
      } else if (s['phase'] == 'choosing_token') {
        final me = (s['players'] as List).firstWhere((p) => p['id'] == id);
        final token = (me['tokens'] as List).firstWhere((t) => t['isFinished'] != true);
        _send('move_token', {'tokenId': token['id']});
      }
    });
    _send('join_game', {'name': 'Bot', 'roomCode': roomCode});
  }

  Future<void> close() => _channel.sink.close();
}

Future<T> _waitFor<T>(Stream<Map<String, dynamic>> events, String name) => events
    .firstWhere((e) => e['event'] == name)
    .then((e) => e['data'] as T)
    .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('no $name'));

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding fakes every HTTP request (WebSockets included);
    // this test talks to a real server.
    HttpOverrides.global = null;
    // No audio or haptics plugins in a test VM.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
  });

  test('app plays a full online match against the real server', () async {
    SharedPreferences.setMockInitialValues(
        {'player_name': 'App', 'sound_enabled': false, 'vibration_enabled': false});
    await PrefsService.init();

    final socket = SocketService.instance;
    final bot = _Bot(_url!);
    final created = _waitFor<Map<String, dynamic>>(socket.events, 'game_created');
    await socket.connect(_url!);
    socket.send('create_game', {'name': 'App', 'maxPlayers': 2, 'testMode': true});
    final roomCode = (await created)['roomCode'] as String;
    expect(roomCode, isNotEmpty);

    final engine = GameEngine(
      board: mediumBoard.build(),
      players: [],
    );
    final controller = NetworkGameController(engine: engine, socketService: socket);
    addTearDown(() async {
      controller.dispose();
      socket.disconnect();
      await bot.close();
    });

    await bot.join(roomCode);
    // Test rooms start every token one cell from home: a 1 finishes it.
    socket.send('debug_set_dice', {'value': 1});

    // Play the app's turns through the controller, as the UI buttons do.
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (engine.phase != GamePhase.finished || controller.myFinishPosition == null) {
      if (DateTime.now().isAfter(deadline)) {
        fail('match did not finish: phase ${engine.phase}, '
            'finish ${controller.myFinishPosition}, players ${engine.players.length}');
      }
      if (controller.isMyTurn && !controller.rollingDice) {
        if (engine.phase == GamePhase.idle) {
          await controller.rollDice();
        } else if (engine.phase == GamePhase.choosing_token &&
            controller.movableTokenIds.isNotEmpty) {
          await controller.selectToken(controller.movableTokenIds.first);
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await bot.finished.future.timeout(const Duration(seconds: 10));

    // The client's view matches what the server reported.
    expect(engine.players, hasLength(2));
    expect(engine.players.map((p) => p.id), containsAll([PrefsService.playerId, bot.id]));
    expect(controller.myFinishPosition, anyOf(1, 2));
    expect(engine.finisherIds, isNotEmpty);
    final me = engine.players.firstWhere((p) => p.id == PrefsService.playerId);
    if (controller.myFinishPosition == 1) {
      expect(me.tokens.every((t) => t.isFinished), isTrue);
      expect(engine.finisherIds.first, PrefsService.playerId);
    }
  }, skip: _url == null ? 'set PARCHIS_E2E_URL to run against a server' : false,
      timeout: const Timeout(Duration(minutes: 3)));

  test('a lone player in a public room can fill it with AI after the wait', () async {
    SharedPreferences.setMockInitialValues(
        {'player_name': 'Solo', 'sound_enabled': false, 'vibration_enabled': false});
    await PrefsService.init();

    final socket = SocketService.instance;
    addTearDown(socket.disconnect);
    await socket.connect(_url!);
    socket.send('find_match', {'name': 'Solo', 'maxPlayers': 3});

    // The server offers AI only after its wait (45 s), never on its own.
    final offered = await socket.events
        .where((e) => e['event'] == 'game_state')
        .map((e) => e['data'] as Map<String, dynamic>)
        .firstWhere((s) => s['canFillWithAi'] == true)
        .timeout(const Duration(seconds: 70));
    expect(offered['phase'], 'idle');
    expect(offered['players'] as List, hasLength(1));

    final engine = GameEngine(board: mediumBoard.build(), players: []);
    final controller = NetworkGameController(engine: engine, socketService: socket);
    addTearDown(controller.dispose);

    socket.send('fill_with_ai');
    final started = await socket.events
        .where((e) => e['event'] == 'game_state')
        .map((e) => e['data'] as Map<String, dynamic>)
        .firstWhere((s) => s['phase'] != 'idle')
        .timeout(const Duration(seconds: 10));
    expect(started['filledWithAi'], isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // The app's controller sees the AI seats as AI.
    expect(engine.players, hasLength(3));
    expect(engine.players.where((p) => p.isAI), hasLength(2));
    expect(engine.players.firstWhere((p) => !p.isAI).id, PrefsService.playerId);
  }, skip: _url == null ? 'set PARCHIS_E2E_URL to run against a server' : false,
      timeout: const Timeout(Duration(minutes: 2)));
}
