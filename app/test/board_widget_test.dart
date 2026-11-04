import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/config/language_provider.dart';
import 'package:frontend_parchis/game/logic/game_controller.dart';
import 'package:frontend_parchis/game/logic/game_engine.dart';
import 'package:frontend_parchis/game/models/player.dart';
import 'package:frontend_parchis/game/widgets/board_widget.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'sound_enabled': false});
    await PrefsService.init();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
  });

  // Online the board is replaced in place when the server's game_state
  // arrives, after the board widget was first built.
  testWidgets('the board redraws when the server swaps in a larger board', (tester) async {
    final engine = GameEngine(board: easyBoard.build(), players: []);
    final controller = LocalGameController(engine: engine);
    controller.setPlayers([
      Player(id: '1', name: 'A', index: 0, tokenAsset: 'assets/tokens/red.png'),
      Player(id: '2', name: 'B', index: 1, tokenAsset: 'assets/tokens/blue.png'),
    ]);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider<GameController>.value(value: controller),
      ],
      child: MaterialApp(
        home: Scaffold(body: BoardWidget(board: engine.board, players: engine.players)),
      ),
    ));
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.widget<GridView>(find.byType(GridView)).childrenDelegate.estimatedChildCount, 49);

    engine.board.cells
      ..clear()
      ..addAll(mediumBoard.build().cells);
    engine.players[0].tokens[0].position = 80; // beyond the old board
    controller.notifyListeners();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.widget<GridView>(find.byType(GridView)).childrenDelegate.estimatedChildCount, 100);
    controller.dispose();
  });
}
