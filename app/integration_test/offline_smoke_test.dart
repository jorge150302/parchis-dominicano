// The real app on an Android device or emulator: Firebase, plugins and
// the platform for real. Same flow as test/offline_flow_test.dart.
//   flutter test integration_test   (with a device or emulator attached)
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/flows/offline_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline: menu -> 2 players vs AI -> the match plays', (tester) async {
    // A returning player: skip the welcome and tutorial dialogs.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', 'Prueba');
    await prefs.setBool('is_first_time', false);
    await prefs.setBool('sound_enabled', false);
    await prefs.setBool('vibration_enabled', false);

    app.main();
    await playOfflineAgainstAi(tester);
  });
}
