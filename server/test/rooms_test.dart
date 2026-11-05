import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:parchis_server/entitlements.dart';
import 'package:parchis_server/match_results.dart';
import 'package:parchis_server/rooms.dart';
import 'package:parchis_server/server_stats.dart';
import 'package:test/test.dart';

/// In-memory client: records every event the server sends it.
class FakeConnection implements ClientConnection {
  FakeConnection(this.clientId);
  final String clientId;
  final received = <Map<String, dynamic>>[];
  bool closed = false;

  @override
  void send(String message) =>
      received.add(jsonDecode(message) as Map<String, dynamic>);

  @override
  void close() => closed = true;

  List<Map<String, dynamic>> events(String name) => [
        for (final e in received)
          if (e['event'] == name) e
      ];

  Map<String, dynamic>? last(String name) {
    final list = events(name);
    return list.isEmpty ? null : list.last['data'] as Map<String, dynamic>;
  }

  List<String> get errorCodes =>
      [for (final e in events('error')) '${e['data']['code']}'];

  Map<String, dynamic>? get state => last('game_state');

  Map<String, dynamic> seat(String id) => (state!['players'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['id'] == id);
}

void main() {
  late FakeAsync clock;

  /// Sends [event] from [conn] (optionally claiming another [asId]).
  void say(
    FakeConnection conn,
    String event, {
    Map<String, dynamic>? data,
    String? asId,
    String? token,
    int? build,
  }) {
    handleClientMessage(
      conn,
      jsonEncode({
        'event': event,
        'clientId': asId ?? conn.clientId,
        'data': data,
        if (token != null) 'idToken': token,
        if (build != null) 'build': build,
      }),
    );
    clock.flushMicrotasks();
  }

  /// Creates a room for [ids] (first id hosts); returns connections in order.
  List<FakeConnection> startRoom(
    List<String> ids, {
    bool testMode = false,
    bool withTokens = false,
  }) {
    final conns = [for (final id in ids) FakeConnection(id)];
    say(
      conns.first,
      'create_game',
      data: {'maxPlayers': ids.length, if (testMode) 'testMode': true},
      token: withTokens ? ids.first : null,
    );
    final code = conns.first.last('game_created')!['roomCode'] as String;
    for (final c in conns.skip(1)) {
      say(
        c,
        'join_game',
        data: {'roomCode': code},
        token: withTokens ? c.clientId : null,
      );
    }
    return conns;
  }

  void run(void Function() body) {
    fakeAsync((async) {
      clock = async;
      body();
      resetRoomsForTest();
      async.flushTimers(flushPeriodicTimers: false);
    });
  }

  setUp(() {
    resetRoomsForTest();
    roomServices = RoomServices(
      uidFromToken: (token) async => token == null ? null : 'uid_$token',
      verifyToken: (_) async => true,
      persistence: false,
      testModeAllowed: true,
    );
    registerRoomStats();
  });

  test('creating and filling a room starts the game for everyone', () {
    run(() {
      final room = startRoom(['a', 'b']);
      for (final c in room) {
        expect(c.state!['phase'], 'rolling');
        expect(c.state!['players'] as List, hasLength(2));
      }
      expect(room[0].state!['currentPlayerId'], 'a');
      expect(room[0].last('game_created')!['roomCode'], matches(r'^\d{5}$'));
    });
  });

  test('only the current player can roll', () {
    run(() {
      final room = startRoom(['a', 'b']);
      say(room[1], 'roll_dice');
      expect(room[0].events('dice_result'), isEmpty);
      say(room[0], 'roll_dice');
      expect(room[0].last('dice_result')!['playerId'], 'a');
    });
  });

  test('a connection cannot act as another player', () {
    run(() {
      final room = startRoom(['a', 'b']);
      say(room[1], 'roll_dice', asId: 'a');
      expect(room[1].errorCodes, contains('CLIENT_MISMATCH'));
      expect(room[0].events('dice_result'), isEmpty);
    });
  });

  test('malformed messages are answered and the connection keeps working', () {
    run(() {
      final c = FakeConnection('x');
      handleClientMessage(c, 'not json {');
      handleClientMessage(c, jsonEncode({'event': 5}));
      handleClientMessage(c, jsonEncode({'event': 'ping', 'level': 'high'}));
      clock.flushMicrotasks();
      expect(c.errorCodes, ['BAD_MESSAGE', 'BAD_MESSAGE', 'BAD_MESSAGE']);
      say(c, 'ping');
      expect(c.events('pong'), hasLength(1));
    });
  });

  test('rooms are isolated from each other', () {
    run(() {
      final one = startRoom(['a1', 'b1']);
      final two = startRoom(['a2', 'b2']);
      say(one[0], 'roll_dice');
      say(one[0], 'chat_message', data: {'message': 'hola'});
      for (final c in two) {
        expect(c.events('dice_result'), isEmpty);
        expect(c.events('chat'), isEmpty);
        for (final e in c.events('game_state')) {
          expect(e['data']['roomCode'], two[0].state!['roomCode']);
        }
      }
    });
  });

  test('a double-tapped move only moves once', () {
    run(() {
      final room = startRoom(['a', 'b'], testMode: true);
      // Test mode puts every token one step from the goal.
      say(room[0], 'debug_set_dice', data: {'value': 1});
      say(room[0], 'roll_dice');
      expect(room[0].state!['phase'], 'choosing_token');
      say(room[0], 'move_token', data: {'tokenId': 0});
      say(room[0], 'move_token', data: {'tokenId': 1});
      clock.elapse(const Duration(seconds: 3));
      final tokens =
          (room[0].seat('a')['tokens'] as List).cast<Map<String, dynamic>>();
      expect(tokens.where((t) => t['isFinished'] == true), hasLength(1));
    });
  });

  test('disconnect hands the seat to auto-play, reconnect hands it back', () {
    run(() {
      final room = startRoom(['a', 'b']);
      handleClientDisconnect(room[1]);
      expect(room[0].seat('b')['isAutoPlaying'], isTrue);

      final back = FakeConnection('b');
      say(back, 'request_sync');
      expect(back.state, isNotNull);
      expect(back.seat('b')['isAutoPlaying'], isFalse);
      expect(back.seat('b')['isAI'], isFalse);
    });
  });

  test('after the grace period the AI takes the seat and the last human wins',
      () {
    run(() {
      final room = startRoom(['a', 'b']);
      handleClientDisconnect(room[1]);
      clock.elapse(const Duration(seconds: 91));
      expect(room[0].seat('b')['isAI'], isTrue);
      expect(room[0].last('you_finished')!['position'], 1);

      final late = FakeConnection('b');
      say(late, 'request_sync');
      expect(late.errorCodes, contains('MATCH_NOT_FOUND'));
    });
  });

  test('reconnecting resumes the newest room, not an abandoned one', () {
    run(() {
      final old = startRoom(['me', 'x']);
      handleClientDisconnect(old[0]); // still in grace in the old room
      final fresh = startRoom(['me', 'y']);
      final freshCode = fresh[0].state!['roomCode'];

      handleClientDisconnect(fresh[0]);
      final back = FakeConnection('me');
      say(back, 'request_sync');
      expect(back.state!['roomCode'], freshCode);
    });
  });

  test('a seat can only be resumed by the account that owns it', () {
    run(() {
      final room = startRoom(['a', 'b'], withTokens: true);
      handleClientDisconnect(room[1]);
      final thief = FakeConnection('b');
      say(thief, 'request_sync', token: 'mallory');
      expect(thief.errorCodes, contains('CANNOT_REJOIN'));
      final owner = FakeConnection('b');
      say(owner, 'request_sync', token: 'b');
      expect(owner.state, isNotNull);
    });
  });

  test('surrender: the game goes on with the AI and the room is told', () {
    run(() {
      final room = startRoom(['a', 'b', 'c']);
      say(room[1], 'surrender');
      expect(room[1].events('surrendered'), hasLength(1));
      expect(room[0].seat('b')['isAI'], isTrue);
      expect(room[0].state!['phase'], isNot('finished'));
      final notices = room[0]
          .events('game_event')
          .where((e) => e['data']['message'] == 'player_surrendered_msg');
      expect(notices, hasLength(1));
    });
  });

  test('surrendering on your own turn hands it to the AI right away', () {
    run(() {
      final room = startRoom(['a', 'b', 'c']);
      say(room[0], 'surrender');
      // The AI's short timer, not the 20 s human one.
      clock.elapse(const Duration(seconds: 5));
      expect(room[1].events('dice_result').map((e) => e['data']['playerId']),
          contains('a'));
    });
  });

  test('disconnecting on your own turn hands it to auto-play right away', () {
    run(() {
      final room = startRoom(['a', 'b']);
      handleClientDisconnect(room[0]);
      clock
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 5));
      expect(room[1].events('dice_result').map((e) => e['data']['playerId']),
          contains('a'));
    });
  });

  test('every player is told their final position once, with or without an '
      'account', () {
    run(() {
      final room = startRoom(['a', 'b'], testMode: true);
      // Test rooms start one cell from home; a 1 finishes a token.
      for (var i = 0; i < 40 && room[0].state!['phase'] != 'finished'; i++) {
        final current = room[0].state!['currentPlayerId'];
        final conn = room.firstWhere((c) => c.clientId == current);
        if (room[0].state!['phase'] == 'rolling') {
          say(conn, 'debug_set_dice', data: {'value': 1});
          say(conn, 'roll_dice');
        } else if (room[0].state!['phase'] == 'choosing_token') {
          final me = conn.seat(conn.clientId);
          final token = (me['tokens'] as List)
              .firstWhere((t) => t['isFinished'] != true);
          say(conn, 'move_token', data: {'tokenId': token['id']});
        }
        clock.elapse(const Duration(seconds: 2));
      }
      expect(room[0].state!['phase'], 'finished');
      for (final c in room) {
        expect(c.events('you_finished'), hasLength(1), reason: c.clientId);
      }
      expect(
        {for (final c in room) c.last('you_finished')!['position']},
        {1, 2},
      );
    });
  });

  group('filling a public room with AI', () {
    /// A public room for [size] with only [conn] in it.
    FakeConnection waitAlone(String id, {int size = 4}) {
      final conn = FakeConnection(id);
      say(conn, 'find_match', data: {'maxPlayers': size}, token: id);
      expect(conn.state!['phase'], 'idle');
      return conn;
    }

    test('is offered only after the wait, and never automatic', () {
      run(() {
        final me = waitAlone('a');
        say(me, 'fill_with_ai');
        expect(me.errorCodes, ['AI_FILL_UNAVAILABLE']);
        expect(me.state!['canFillWithAi'], isFalse);

        clock.elapse(const Duration(seconds: 46));
        expect(me.state!['canFillWithAi'], isTrue);
        // Offering it seats nobody.
        expect(me.state!['players'] as List, hasLength(1));
        expect(me.state!['phase'], 'idle');
      });
    });

    test('fills the empty seats with marked AI players and starts', () {
      run(() {
        final me = waitAlone('a');
        clock.elapse(const Duration(seconds: 46));
        say(me, 'fill_with_ai');

        final players =
            (me.state!['players'] as List).cast<Map<String, dynamic>>();
        expect(players, hasLength(4));
        expect(players.where((p) => p['isAI'] == true), hasLength(3));
        expect(me.seat('a')['isAI'], isFalse);
        expect(me.state!['phase'], 'rolling');
        expect(me.state!['filledWithAi'], isTrue);
        expect(me.state!['canFillWithAi'], isFalse);

        // The AI seats play their own turns once the human's has passed.
        clock.elapse(const Duration(seconds: 40));
        final rollers = me.events('dice_result').map((e) => e['data']['playerId']);
        expect(rollers.where((id) => '$id'.startsWith('ai_')), isNotEmpty);

        // A filled room is no longer offered to matchmaking.
        final late = FakeConnection('late');
        say(late, 'find_match', data: {'maxPlayers': 4}, token: 'late');
        expect(late.state!['roomCode'], isNot(me.state!['roomCode']));
      });
    });

    test('is not available in private rooms or to outsiders', () {
      run(() {
        final room = startRoom(['a', 'b', 'c']);
        clock.elapse(const Duration(seconds: 46));
        say(room[0], 'fill_with_ai');
        expect(room[0].errorCodes, ['AI_FILL_UNAVAILABLE']);

        final outsider = FakeConnection('x');
        say(outsider, 'fill_with_ai');
        expect(outsider.errorCodes, ['AI_FILL_UNAVAILABLE']);
      });
    });

    test('pays half the XP', () {
      run(() {
        final me = waitAlone('a', size: 2);
        clock.elapse(const Duration(seconds: 46));
        say(me, 'fill_with_ai');
        say(me, 'toggle_auto_play', data: {'value': true});
        for (var i = 0; i < 4 * 3600 && me.state!['phase'] != 'finished'; i++) {
          clock.elapse(const Duration(seconds: 1));
        }
        expect(me.state!['phase'], 'finished');
        final result = me.last('you_finished')!;
        final rank = result['position'] as int;
        expect(
          result['xpAwarded'],
          onlineMatchXp(position: rank - 1, totalPlayers: 2, vsAi: true),
        );
        expect(
          onlineMatchXp(position: 0, totalPlayers: 2, vsAi: true),
          onlineMatchXp(position: 0, totalPlayers: 2) ~/ 2,
        );
      });
    });
  });

  test('a lobby that never fills expires and is released', () {
    run(() {
      final host = FakeConnection('h');
      say(host, 'create_game', data: {'maxPlayers': 4});
      expect(roomsForTest, hasLength(1));
      clock.elapse(const Duration(minutes: 16));
      expect(host.errorCodes, contains('LOBBY_TIMEOUT'));
      expect(roomsForTest, isEmpty);
    });
  });

  test('everything is released once all players leave', () {
    run(() {
      final room = startRoom(['a', 'b']);
      for (final c in room) {
        handleClientDisconnect(c);
      }
      clock.elapse(const Duration(minutes: 6));
      final stats = serverStats();
      expect(stats['rooms'], 0);
      expect(stats['connections'], 0);
      expect(stats['reconnectionTimers'], 0);
    });
  });

  test('test rooms are refused when the server does not allow them', () {
    run(() {
      roomServices = RoomServices(
        uidFromToken: (_) async => null,
        verifyToken: (_) async => true,
        persistence: false,
        testModeAllowed: false,
      );
      final room = startRoom(['a', 'b'], testMode: true);
      say(room[0], 'debug_set_dice', data: {'value': 6});
      say(room[0], 'roll_dice');
      // Without test mode tokens start at home, not next to the goal.
      expect(
        (room[0].seat('a')['tokens'] as List).every((t) => t['position'] == 0),
        isTrue,
      );
    });
  });

  group('minimum app build', () {
    RoomServices withMinimum(int build) => RoomServices(
          uidFromToken: (_) async => null,
          verifyToken: (_) async => true,
          persistence: false,
          testModeAllowed: false,
          minClientBuild: build,
        );

    test('is off by default: any build, or none, can play', () {
      run(() {
        final c = FakeConnection('a');
        say(c, 'create_game', data: {'maxPlayers': 2});
        expect(c.events('game_created'), hasLength(1));
      });
    });

    test('older or unversioned apps are told to update; ping still works', () {
      run(() {
        roomServices = withMinimum(5);
        final old = FakeConnection('old');
        say(old, 'create_game', data: {'maxPlayers': 2}, build: 4);
        final legacy = FakeConnection('legacy');
        say(legacy, 'create_game', data: {'maxPlayers': 2});
        final current = FakeConnection('new');
        say(current, 'create_game', data: {'maxPlayers': 2}, build: 5);

        expect(old.errorCodes, ['UPDATE_REQUIRED']);
        expect(legacy.errorCodes, ['UPDATE_REQUIRED']);
        expect(current.events('game_created'), hasLength(1));
        say(old, 'ping');
        expect(old.events('pong'), hasLength(1));
      });
    });
  });

  test('players only get the dice skins they own', () {
    run(() {
      final store = MemoryEntitlementStore();
      roomServices = RoomServices(
        uidFromToken: (token) async => token == null ? null : 'uid_$token',
        verifyToken: (_) async => true,
        persistence: false,
        testModeAllowed: false,
        entitlements: EntitlementService(
          store,
          catalog: const [
            ...defaultCatalog,
            CatalogItem('dice_gold', ItemType.dice),
          ],
        ),
      );
      store.grant('uid_a', 'dice_gold', source: 'test');
      clock.flushMicrotasks();

      final a = FakeConnection('a');
      final b = FakeConnection('b');
      say(a, 'create_game',
          data: {'maxPlayers': 2, 'diceSkin': 'dice_gold'}, token: 'a');
      final code = a.last('game_created')!['roomCode'];
      say(b, 'join_game',
          data: {'roomCode': code, 'diceSkin': 'dice_gold'}, token: 'b');

      expect(b.seat('a')['diceSkin'], 'dice_gold');
      expect(b.seat('b')['diceSkin'], defaultDiceSkin);
    });
  });
}
