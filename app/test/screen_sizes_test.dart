// Every main screen laid out on Android phones and tablets, at normal and
// large text (accessibility 130%). Fails on any layout overflow, listing
// each screen, size and text scale where it happens.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/config/language_provider.dart';
import 'package:frontend_parchis/game/logic/game_controller.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/game/screen/game_screen.dart';
import 'package:frontend_parchis/game/widgets/board_widget.dart';
import 'package:frontend_parchis/menu/main_menu_screen.dart';
import 'package:frontend_parchis/menu/online_lobby_screen.dart';
import 'package:frontend_parchis/menu/player_selection_screen.dart';
import 'package:frontend_parchis/screens/privacy_policy_screen.dart';
import 'package:frontend_parchis/service/auth_service.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/service/sync_queue_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-out account, without Firebase.
class _NoFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}

class _NoGoogle extends Fake implements GoogleSignIn {}

class _NoFirestore extends Fake implements FirebaseFirestore {}

/// Logical sizes (dp) of common Android devices.
const devices = {
  'small phone 320x568': Size(320, 568),
  'phone 360x800': Size(360, 800),
  'large phone 412x915': Size(412, 915),
  'tablet portrait 800x1280': Size(800, 1280),
  'tablet landscape 1280x800': Size(1280, 800),
};

const textScales = [1.0, 1.3];

/// Text shown by translation [key] (Spanish), whatever its letter case.
Finder textOf(String key) {
  final text = LanguageProvider.translations[Language.es]![key]!.toLowerCase();
  return find.byWidgetPredicate((w) => w is Text && (w.data ?? '').toLowerCase().contains(text));
}

typedef Screen = ({Widget Function() build, Finder Function() shows, Map<String, Object> prefs});

final screens = <String, Screen>{
  'main menu': (build: () => const MainMenuScreen(), shows: () => textOf('offline_mode'), prefs: const {}),
  'main menu, first launch': (
    build: () => const MainMenuScreen(),
    shows: () => textOf('welcome_to_parche'),
    prefs: const {'player_name': '', 'is_first_time': true},
  ),
  'player selection': (build: () => const PlayerSelectionScreen(), shows: () => textOf('select_player_count'), prefs: const {}),
  'online lobby': (build: () => const OnlineLobbyScreen(), shows: () => textOf('multiplayer_online'), prefs: const {}),
  'privacy policy': (build: () => const PrivacyPolicyScreen(), shows: () => textOf('privacy_policy_title'), prefs: const {}),
  'offline game (4 players)': (
    build: () => ChangeNotifierProvider<GameController>(
          create: (_) => LocalGameController(
            engine: GameEngine(board: mediumBoard.build(), players: []),
            vsAI: true,
          ),
          child: const GameScreen(playerCount: 4),
        ),
    shows: () => find.byType(BoardWidget),
    prefs: const {},
  ),
};

/// Tests render text with a placeholder font whose glyphs are full squares,
/// far wider than real text, so every label "overflows". Load Roboto (the
/// app's Android font, bundled in test/fonts with its license: CI's Flutter
/// SDK doesn't always carry it) to measure like a phone does.
Future<void> loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final weight in ['light', 'regular', 'medium', 'bold', 'black']) {
    final file = File('test/fonts/roboto-$weight.ttf');
    loader.addFont(file.readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

void main() {
  late AuthService auth;

  setUpAll(() async {
    await loadRoboto();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  const basePrefs = <String, Object>{
    'player_name': 'Jugadora',
    'is_first_time': false,
    'language_code': 'es',
    'sound_enabled': false,
    'vibration_enabled': false,
  };

  setUp(() {
    auth = AuthService(auth: _NoFirebaseAuth(), googleSignIn: _NoGoogle(), db: _NoFirestore());
  });

  tearDown(() => socketService.disconnect());

  Future<List<String>> layoutProblems(
    WidgetTester tester,
    Screen screen,
    Size size,
    double textScale,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({...basePrefs, ...screen.prefs});
    await PrefsService.init();
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    addTearDown(tester.view.reset);

    final problems = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final what = details.exceptionAsString().split('\n').first;
      // "The relevant error-causing widget was: Row  lib/…dart:123:9"
      final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString())?.group(0);
      problems.add(where == null ? what : '$what ($where)');
    };
    try {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SocketService>.value(value: socketService),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider(create: (_) => SyncQueueService(auth)),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen.build(),
        ),
      ));
      // Entrance animations and the first post-frame work.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      // An empty screen would pass any layout check.
      if (screen.shows().evaluate().isEmpty) problems.add('expected content is not on screen');
    } finally {
      FlutterError.onError = previous;
    }
    // Leave no route timers behind for the next size.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    return problems;
  }

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name lays out on every device and text size', (tester) async {
      final failures = <String>[];
      for (final MapEntry(key: device, value: size) in devices.entries) {
        for (final scale in textScales) {
          for (final p in await layoutProblems(tester, screen, size, scale)) {
            failures.add('$device, text ${(scale * 100).round()}%: $p');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.toSet().join('\n'));
    });
  }
}
