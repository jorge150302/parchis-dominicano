// The emulator smoke flow (integration_test/) run as a widget test: fake
// Firebase and fake time, so the taps and texts are checked on every PR in
// seconds, before the emulators run the same flow on the real app.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/main.dart';
import 'package:frontend_parchis/service/auth_service.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flows/offline_flow.dart';

class _NoFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
}

class _NoGoogle extends Fake implements GoogleSignIn {}

class _NoFirestore extends Fake implements FirebaseFirestore {}

void main() {
  setUp(() async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    SharedPreferences.setMockInitialValues({
      'player_name': 'Prueba',
      'is_first_time': false,
      'language_code': 'es',
      'sound_enabled': false,
      'vibration_enabled': false,
    });
    await PrefsService.init();
  });

  tearDown(() => socketService.disconnect());

  testWidgets('offline: menu -> 2 players vs AI -> the match plays', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(412, 915) * 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MyApp(
      auth: AuthService(auth: _NoFirebaseAuth(), googleSignIn: _NoGoogle(), db: _NoFirestore()),
    ));
    await playOfflineAgainstAi(tester);

    // Leave the match so no game timers outlive the test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
