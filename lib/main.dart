import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'menu/main_menu_screen.dart';
import 'menu/player_selection_screen.dart';

import 'game/screen/game_screen.dart';
import 'game/logic/game_controller.dart';
import 'game/logic/game_engine.dart';
import 'game/logic/board_generator.dart';
import 'game/logic/board_presets.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parché',
      initialRoute: '/',

      routes: {
        '/': (_) => const SplashScreen(),
        '/menu': (_) => const MainMenuScreen(),
        '/players': (_) => const PlayerSelectionScreen(),
      },

      /// 🔥 SOLO cambiamos esto
      onGenerateRoute: (settings) {
        if (settings.name == '/game') {
          final int playersCount = settings.arguments as int;

          final engine = GameEngine(
            board: generateBoard(classicActionPositions, classicActions),
            players: [],
          );

          return MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => GameController(engine),
              child: GameScreen(playerCount: playersCount),
            ),
          );
        }

        return null;
      },
    );
  }
}
