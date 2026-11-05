import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'package:frontend_parchis/menu/online_lobby_screen.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/auth_service.dart';
import 'package:frontend_parchis/service/sync_queue_service.dart';
import 'package:provider/provider.dart';

import 'config/app_info.dart';
import 'config/language_provider.dart';
import 'screens/splash_screen.dart';
import 'menu/main_menu_screen.dart';
import 'menu/player_selection_screen.dart';
import 'screens/privacy_policy_screen.dart';

import 'game/screen/game_screen.dart';
import 'game/logic/game_controller.dart';
import 'game/logic/game_engine.dart';
import 'game/logic/level_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.init();
  await AppInfo.load();
  
  // Bloquear orientación en modo vertical (Portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Requires google-services.json in android/app/
  // Run `flutterfire configure` or download it from your Firebase Console.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // getIdToken() returns a cached token and silently refreshes it once expired.
  socketService.idTokenProvider = () async => FirebaseAuth.instance.currentUser?.getIdToken();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.auth});

  /// The app's account service; tests pass one built without Firebase.
  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: socketService),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => auth ?? AuthService()),
        ChangeNotifierProxyProvider<AuthService, SyncQueueService>(
          create: (ctx) => SyncQueueService(ctx.read<AuthService>()),
          update: (ctx, auth, prev) => prev ?? SyncQueueService(auth),
        ),
      ],
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Parché',
          initialRoute: '/', 
          routes: {
            '/': (_) => const SplashScreen(),
            '/menu': (_) => const MainMenuScreen(),
            '/players': (_) => const PlayerSelectionScreen(),
            '/online_lobby': (_) => const OnlineLobbyScreen(),
            '/privacy': (_) => const PrivacyPolicyScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/game') {
              final args = settings.arguments as Map<String, dynamic>?;
              
              int playersCount = args?['playerCount'] ?? 2;
              String? roomCode = args?['roomCode'];
              bool vsAI = args?['vsAI'] ?? false;
              List<String>? playerNames = args?['playerNames'];
              bool isResume = args?['isResume'] ?? false;
              bool isRejoin = args?['isRejoin'] ?? false;
              bool isTutorial = args?['isTutorial'] ?? false;
              Map<String, dynamic>? savedState = args?['savedState'];
              // Restore difficulty from saved state when resuming, else use route arg
              final savedDifficultyIndex = savedState?['difficulty'] as int?;
              final difficulty = savedDifficultyIndex != null
                  ? GameDifficulty.values[savedDifficultyIndex]
                  : (args?['difficulty'] as GameDifficulty?) ?? GameDifficulty.medium;

              // Online rooms switch to the server's board on the first game_state.
              final board = switch (difficulty) {
                GameDifficulty.easy => easyBoard,
                GameDifficulty.hard => hardBoard,
                GameDifficulty.medium => mediumBoard,
              }.build();
              late final GameEngine engine;

              if (isResume && savedState != null) {
                engine = GameEngine.fromSavedState(savedState, board);
              } else {
                engine = GameEngine(board: board, players: []);
              }

              return MaterialPageRoute(
                builder: (context) {
                  return ChangeNotifierProvider<GameController>(
                    create: (_) => (roomCode != null)
                        ? NetworkGameController(engine: engine, socketService: socketService)
                        : LocalGameController(engine: engine, vsAI: vsAI, isTutorial: isTutorial, difficulty: difficulty),
                    child: GameScreen(
                      playerCount: playersCount,
                      roomCode: roomCode,
                      playerNames: playerNames,
                      isResume: isResume,
                      isRejoin: isRejoin,
                      isTutorial: isTutorial,
                      difficulty: difficulty,
                    ),
                  );
                },
              );
            }
            return null;
          },
        );
      },
    );
  }
}
