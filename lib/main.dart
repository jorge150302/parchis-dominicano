import 'package:flutter/material.dart';
import 'package:frontend_parchis/menu/online_lobby_screen.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'menu/main_menu_screen.dart';
import 'menu/player_selection_screen.dart';

import 'game/screen/game_screen.dart';
import 'game/logic/game_controller.dart';
import 'game/logic/game_engine.dart';
import 'game/logic/board_generator.dart';
import 'game/logic/board_presets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefsService.init(); 
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: socketService),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Parché',
        initialRoute: '/', 
        routes: {
          '/': (_) => const SplashScreen(),
          '/menu': (_) => const MainMenuScreen(),
          '/players': (_) => const PlayerSelectionScreen(),
          '/online_lobby': (_) => const OnlineLobbyScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/game') {
            final args = settings.arguments;
            int playersCount = 2;
            String? roomCode;
            bool vsAI = false;

            if (args is int) {
              playersCount = args;
            } else if (args is Map<String, dynamic>) {
              playersCount = args['playerCount'] ?? 2;
              roomCode = args['roomCode'];
              vsAI = args['vsAI'] ?? false;
            }

            final engine = GameEngine(
              board: generateBoard(classicActionPositions, classicActions),
              players: [],
            );

            return MaterialPageRoute(
              builder: (context) {
                return ChangeNotifierProvider<GameController>(
                  create: (_) => (roomCode != null)
                      ? NetworkGameController(engine: engine, socketService: socketService)
                      : LocalGameController(engine: engine, vsAI: vsAI),
                  child: GameScreen(
                    playerCount: playersCount,
                    roomCode: roomCode,
                  ),
                );
              },
            );
          }
          return null;
        },
      ),
    );
  }
}
