import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:frontend_parchis/menu/online_lobby_screen.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/auth_service.dart';
import 'package:frontend_parchis/service/sync_queue_service.dart';
import 'package:provider/provider.dart';

import 'config/language_provider.dart';
import 'screens/splash_screen.dart';
import 'menu/main_menu_screen.dart';
import 'menu/player_selection_screen.dart';
import 'screens/privacy_policy_screen.dart';

import 'game/screen/game_screen.dart';
import 'game/logic/game_controller.dart';
import 'game/logic/game_engine.dart';
import 'game/logic/board_generator.dart';
import 'game/logic/board_actions_config.dart';
import 'game/logic/level_manager.dart';
import 'game/models/board_action.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.init();
  // Requires google-services.json in android/app/
  // Run `flutterfire configure` or download it from your Firebase Console.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: socketService),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
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
              bool isTutorial = args?['isTutorial'] ?? false;
              Map<String, dynamic>? savedState = args?['savedState'];
              // Restore difficulty from saved state when resuming, else use route arg
              final savedDifficultyIndex = savedState?['difficulty'] as int?;
              final difficulty = savedDifficultyIndex != null
                  ? GameDifficulty.values[savedDifficultyIndex]
                  : (args?['difficulty'] as GameDifficulty?) ?? GameDifficulty.medium;

              final List<int> actionPositions;
              final List<BoardAction> actions;
              final int totalCells;

              switch (difficulty) {
                case GameDifficulty.easy:
                  actionPositions = easyActionPositions;
                  actions = easyActions;
                  totalCells = 50;
                case GameDifficulty.hard:
                  actionPositions = hardActionPositions;
                  actions = hardActions;
                  totalCells = 100;
                case GameDifficulty.medium:
                  actionPositions = mediumActionPositions;
                  actions = mediumActions;
                  totalCells = 100;
              }

              final board = generateBoard(actionPositions, actions, totalCells: totalCells);
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
