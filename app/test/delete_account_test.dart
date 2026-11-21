// Deleting the account: confirm with Google, then the server deletes
// everything (POST /delete_account); the app only signs out after the
// server says it's done.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/service/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fake_firebase.dart';
import 'helpers/screen_harness.dart';

void main() {
  late FakeAuth auth;
  late FakeUser user;
  late FakeGoogle google;
  late List<http.Request> requests;

  setUp(() async {
    await usePrefs();
    FakeUser.idToken = Completer<String?>()..complete('fresh-token');
    user = FakeUser();
    auth = FakeAuth()..signedIn = user;
    google = FakeGoogle();
    requests = [];
  });

  AuthService service(Future<http.Response> Function(http.Request) server) =>
      AuthService(
        auth: auth,
        googleSignIn: google,
        db: FakeDb(),
        hasConnection: () async => true,
        httpClient: MockClient((r) {
          requests.add(r);
          return server(r);
        }),
      );

  test(
    'confirms with Google, then the server deletes and the app signs out',
    () async {
      final s = service((_) async => http.Response('{"deleted":true}', 200));
      expect(await s.deleteAccount(), DeleteAccountStatus.success);

      expect(user.reauthentications, 1, reason: 'a fresh sign-in first');
      final request = requests.single;
      expect(request.url.path, '/delete_account');
      expect(jsonDecode(request.body), {'id_token': 'fresh-token'});
      expect(auth.currentUser, isNull, reason: 'signed out once deleted');
      expect(google.calls, contains('signOut'));
    },
  );

  test('a server refusal keeps the user signed in', () async {
    final s = service(
      (_) async => http.Response('{"error":"reauth_required"}', 403),
    );
    expect(await s.deleteAccount(), DeleteAccountStatus.error);
    expect(auth.currentUser, isNotNull);
  });

  test('closing the Google picker cancels without asking the server', () async {
    google.cancel = true;
    final s = service((_) async => http.Response('', 200));
    expect(await s.deleteAccount(), DeleteAccountStatus.cancelled);
    expect(requests, isEmpty);
    expect(auth.currentUser, isNotNull);
  });

  test(
    'choosing another Google account says so, and deletes nothing',
    () async {
      user.reauthError = 'user-mismatch';
      final s = service((_) async => http.Response('', 200));
      expect(await s.deleteAccount(), DeleteAccountStatus.wrongAccount);
      expect(requests, isEmpty);
    },
  );

  test('no connection to the server reads as offline', () async {
    final s = service((_) async => throw http.ClientException('no route'));
    expect(await s.deleteAccount(), DeleteAccountStatus.offline);
    expect(auth.currentUser, isNotNull);
  });
}
