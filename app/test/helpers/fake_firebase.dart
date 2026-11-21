// Minimal Firebase and Google sign-in fakes: one Google account that
// signs in, and a Firestore holding no profile yet (a new account) whose
// read can be held back with [FakeDb.profileRead].
//
// Firestore marks its reference and snapshot types sealed; these minimal
// fakes stand in for one profile read without a Firebase project.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FakeUser extends Fake implements User {
  /// Completes [getIdToken]; left pending, it models a network that never
  /// answers.
  static Completer<String?> idToken = Completer<String?>();

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) => idToken.future;

  /// Set to make re-authentication fail with this Firebase error code.
  String? reauthError;
  int reauthentications = 0;

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    if (reauthError != null) throw FirebaseAuthException(code: reauthError!);
    reauthentications++;
    return FakeCredential(this);
  }

  @override
  String get uid => 'u1';
  @override
  String? get displayName => 'Ana Pérez';
  @override
  String? get photoURL => 'https://example.com/ana.png';
}

class FakeCredential extends Fake implements UserCredential {
  FakeCredential(this.user);
  @override
  final User? user;
}

class FakeAuth extends Fake implements FirebaseAuth {
  User? signedIn;
  @override
  User? get currentUser => signedIn;
  @override
  Stream<User?> authStateChanges() => const Stream.empty();
  @override
  Future<void> signOut() async => signedIn = null;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    signedIn = FakeUser();
    return FakeCredential(signedIn);
  }
}

class FakeAccount extends Fake implements GoogleSignInAccount {
  @override
  GoogleSignInAuthentication get authentication =>
      const GoogleSignInAuthentication(idToken: 'id');
}

class FakeGoogle extends Fake implements GoogleSignIn {
  final calls = <String>[];

  /// The account picker was closed without choosing.
  bool cancel = false;
  @override
  Future<void> signOut() async => calls.add('signOut');
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async => calls.add('initialize');
  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    calls.add('authenticate');
    if (cancel) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    }
    return FakeAccount();
  }
}

/// A Firestore whose profile read waits for [profileRead] to complete.
class FakeDb extends Fake implements FirebaseFirestore {
  final profileRead = Completer<void>();
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      FakeUsers(this);
}

class FakeUsers extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  FakeUsers(this.db);
  final FakeDb db;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _FakeDoc(db);
}

class _FakeDoc extends Fake implements DocumentReference<Map<String, dynamic>> {
  _FakeDoc(this.db);
  final FakeDb db;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    await db.profileRead.future;
    return _FakeMissing();
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}
}

/// A new account: no profile document yet.
class _FakeMissing extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => false;
}
