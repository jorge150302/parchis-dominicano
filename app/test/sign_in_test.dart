// Google sign-in order: the account shows as soon as Firebase signs in,
// before the profile (XP, level) arrives from Firestore; and the network
// check runs alongside Google's setup instead of before it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/main.dart';
import 'package:frontend_parchis/service/auth_service.dart';
import 'package:frontend_parchis/service/socket_service.dart';

import 'flows/offline_flow.dart';
import 'helpers/fake_firebase.dart';
import 'helpers/screen_harness.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => usePrefs());

  test('the account shows before the profile arrives from Firestore', () async {
    final auth = FakeAuth(), db = FakeDb();
    final service = AuthService(
      auth: auth,
      googleSignIn: FakeGoogle(),
      db: db,
      hasConnection: () async => true,
    );
    var notified = 0;
    service.addListener(() => notified++);

    final signIn = service.signInWithGoogle();
    for (var i = 0; i < 5; i++) {
      await _settle();
    }
    expect(service.isSignedIn, isTrue);
    expect(
      notified,
      greaterThan(0),
      reason: 'the menu hears about the sign-in right away',
    );
    expect(service.profile, isNull, reason: 'Firestore has not answered yet');

    db.profileRead.complete();
    expect(await signIn, SignInStatus.success);
    expect(service.profile?.displayName, 'Ana');
  });

  test(
    "Google's setup starts while the network check is still running",
    () async {
      final google = FakeGoogle();
      final network = Completer<bool>();
      final db = FakeDb()..profileRead.complete();
      final service = AuthService(
        auth: FakeAuth(),
        googleSignIn: google,
        db: db,
        hasConnection: () => network.future,
      );

      final signIn = service.signInWithGoogle();
      await _settle();
      expect(google.calls, [
        'initialize',
      ], reason: 'set up in parallel, not after the check');

      network.complete(true);
      expect(await signIn, SignInStatus.success);
      expect(google.calls, ['initialize', 'authenticate']);
    },
  );

  test('offline: no account picker, no sign-in', () async {
    final google = FakeGoogle(), auth = FakeAuth();
    final service = AuthService(
      auth: auth,
      googleSignIn: google,
      db: FakeDb(),
      hasConnection: () async => false,
    );

    expect(await service.signInWithGoogle(), SignInStatus.offline);
    expect(google.calls, isNot(contains('authenticate')));
    expect(auth.currentUser, isNull);
  });

  testWidgets('a new player goes from Google straight to choosing a name', (
    tester,
  ) async {
    await usePrefs({'player_name': '', 'is_first_time': true});
    // The session check's token request never answers, like a server
    // still waking up: sign-in must not wait for it.
    FakeUser.idToken = Completer<String?>();
    addTearDown(socketService.disconnect);
    final db = FakeDb()..profileRead.complete();
    final auth = AuthService(
      auth: FakeAuth(),
      googleSignIn: FakeGoogle(),
      db: db,
      hasConnection: () async => true,
    );
    await tester.pumpWidget(MyApp(auth: auth));

    final google = find.text('Continuar con Google');
    await pumpUntilFound(tester, google, reason: 'no welcome dialog');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(google);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('step1')),
      findsOneWidget,
      reason: 'still waiting after sign-in',
    );
    expect(
      find
          .byType(EditableText)
          .evaluate()
          .map((e) => (e.widget as EditableText).controller.text),
      contains('Ana'),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
