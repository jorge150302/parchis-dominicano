// The emulator smoke flow (integration_test/) run as a widget test: fake
// Firebase and fake time, so the taps and texts are checked on every PR in
// seconds, before the emulators run the same flow on the real app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/main.dart';
import 'package:frontend_parchis/service/socket_service.dart';

import 'flows/offline_flow.dart';
import 'helpers/screen_harness.dart';

void main() {
  setUp(() async {
    muteAudioPlugins();
    await usePrefs({'player_name': 'Prueba'});
  });

  tearDown(() => socketService.disconnect());

  testWidgets('offline: menu -> 2 players vs AI -> the match plays', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(412, 915) * 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MyApp(auth: signedOutAuth()));
    await playOfflineAgainstAi(tester);

    // Leave the match so no game timers outlive the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
