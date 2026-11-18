// Shared by the screen tests (layout per size, golden screenshots, the
// offline flow): build real app screens without Firebase, plugins or
// network, measuring text with the app's real font.
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

AuthService signedOutAuth() =>
    AuthService(auth: _NoFirebaseAuth(), googleSignIn: _NoGoogle(), db: _NoFirestore());

/// A returning player with sound off, in Spanish.
const basePrefs = <String, Object>{
  'player_name': 'Jugadora',
  'is_first_time': false,
  'language_code': 'es',
  'sound_enabled': false,
  'vibration_enabled': false,
};

Future<void> usePrefs([Map<String, Object> extra = const {}]) async {
  SharedPreferences.resetStatic();
  SharedPreferences.setMockInitialValues({...basePrefs, ...extra});
  await PrefsService.init();
}

/// Answers every audioplayers call (methods and the per-player event
/// channels, whose names are random ids) as a silent success; other
/// channels keep their usual test handlers.
void muteAudioPlugins() {
  const ok = StandardMethodCodec();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.allMessagesHandler =
      (channel, handler, message) {
    if (channel.startsWith('xyz.luan/audioplayers')) {
      return Future.value(ok.encodeSuccessEnvelope(null));
    }
    return handler?.call(message);
  };
}

/// Tests render text with a placeholder font whose glyphs are full squares,
/// far wider than real text, so every label "overflows". Load Roboto (the
/// app's Android font) and Material Icons, both bundled in test/fonts with
/// their licenses (CI's Flutter SDK doesn't carry them), to measure and
/// draw like a phone does.
Future<void> loadRoboto() async {
  Future<ByteData> font(String name) =>
      File('test/fonts/$name').readAsBytes().then((b) => ByteData.view(b.buffer));
  final roboto = FontLoader('Roboto');
  for (final weight in ['light', 'regular', 'medium', 'bold', 'black']) {
    roboto.addFont(font('roboto-$weight.ttf'));
  }
  await roboto.load();
  // Icons too, or they render as empty boxes and an icon change goes unseen.
  await (FontLoader('MaterialIcons')..addFont(font('materialicons-regular.otf'))).load();
}

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
          child: const GameScreen(playerCount: 4, playerNames: ['Jugadora', 'Ana', 'Beto', 'Caro']),
        ),
    shows: () => find.byType(BoardWidget),
    prefs: const {},
  ),
};

/// Builds [screen] on a [size] (dp) device at [textScale], and lets its
/// entrance animations and first post-frame work run.
Future<void> pumpScreen(
  WidgetTester tester,
  Screen screen,
  Size size, {
  double textScale = 1.0,
  double devicePixelRatio = 2,
}) async {
  await usePrefs(screen.prefs);
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = size * devicePixelRatio;
  addTearDown(tester.view.reset);

  final auth = signedOutAuth();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<SocketService>.value(value: socketService),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider(create: (_) => SyncQueueService(auth)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen.build(),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Removes the screen so no route timers outlive it.
Future<void> clearScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
  socketService.disconnect();
}
