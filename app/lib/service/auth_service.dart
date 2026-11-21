import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/user_profile.dart';
import 'network_checker.dart';
import 'prefs_service.dart';

enum SignInStatus { success, offline, error, cancelled }

enum SignOutStatus { success, offline }

enum DeleteAccountStatus { success, offline, error, cancelled, wrongAccount }

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleSignInInit;
  final FirebaseFirestore _db;
  final Future<bool> Function() _hasConnection;
  final http.Client _http;

  UserProfile? _profile;
  bool _needsMigrationDialog = false;
  int _guestXpBeforeMigration = 0;
  bool _profileLoading = false;
  Completer<void>? _profileLoadCompleter;
  bool _wasSignedIn = false;
  StreamSubscription<User?>? _authSub;

  UserProfile? get profile => _profile;
  bool get needsMigrationDialog => _needsMigrationDialog;
  int get guestXpBeforeMigration => _guestXpBeforeMigration;
  bool get isSignedIn => _auth.currentUser != null;
  User? get firebaseUser => _auth.currentUser;

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// [auth], [googleSignIn], [db], [hasConnection] and [httpClient] default
  /// to the real Firebase instances, network check and HTTP client; tests
  /// pass fakes so screens can be built without Firebase.
  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? db,
    Future<bool> Function()? hasConnection,
    http.Client? httpClient,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _http = httpClient ?? http.Client(),
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _db = db ?? FirebaseFirestore.instance,
        _hasConnection = hasConnection ?? NetworkChecker.hasConnection {
    _wasSignedIn = _auth.currentUser != null;
    _authSub = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user != null) {
      bool isTransition = !_wasSignedIn;
      if (isTransition) {
        // Actual sign-in transition — discard any guest XP receipts so they
        // are not synced to the cloud as if they were earned while authenticated.
        PrefsService.pendingSyncReceipts = [];
        debugPrint('[AuthService] Guest receipts cleared on sign-in');
      }
      _wasSignedIn = true;
      await _loadOrCreateProfile(user, checkMigration: isTransition);
    } else {
      _wasSignedIn = false;
      _profile = null;
      notifyListeners();
    }
  }

  /// Runs the native Google account picker and returns a Firebase credential,
  /// or `null` if the user cancelled. google_sign_in 7 must be initialized
  /// once before use; on Android the web client ID comes from
  /// google-services.json.
  Future<AuthCredential?> _googleCredential() async {
    await (_googleSignInInit ??= _googleSignIn.initialize());
    try {
      final account = await _googleSignIn.authenticate();
      return GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<SignInStatus> signInWithGoogle() async {
    // The network check and Google's one-time setup run side by side
    // instead of one after the other.
    final connected = _hasConnection();
    if (!kIsWeb) _googleSignInInit ??= _googleSignIn.initialize();
    if (!await connected) return SignInStatus.offline;

    try {
      final User? user;
      if (kIsWeb) {
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        user = result.user;
      } else {
        final credential = await _googleCredential();
        if (credential == null) return SignInStatus.cancelled;
        user = (await _auth.signInWithCredential(credential)).user;
      }
      if (user == null) return SignInStatus.error;
      // Signed in: show the account (Google photo and name) now; the
      // profile (XP, level, stats) follows from Firestore.
      notifyListeners();
      await _loadOrCreateProfile(user);
      return SignInStatus.success;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') return SignInStatus.offline;
      debugPrint('Google Sign-In FirebaseAuthException: ${e.code}');
      return SignInStatus.error;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return SignInStatus.error;
    }
  }

  Future<SignOutStatus> signOut() async {
    final connected = await NetworkChecker.hasConnection();
    if (!connected) return SignOutStatus.offline;
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
    _profile = null;
    // Wipe local mirror so the next account sign-in cannot inherit this account's XP.
    PrefsService.totalXp = 0;
    PrefsService.playerLevel = 1;
    PrefsService.matchesPlayed = 0;
    PrefsService.tokensCapture = 0;
    PrefsService.wins = 0;
    notifyListeners();
    return SignOutStatus.success;
  }

  /// Atomically deletes the account. Server operations run FIRST; local data
  /// is cleared only after both Firestore and Auth deletion succeed.
  /// Deletes the account. The user confirms with Google first (the server
  /// only accepts a fresh sign-in), then the server deletes the profile,
  /// its history and the Firebase Auth user in one place: the app no longer
  /// deletes Firestore data itself, so it doesn't depend on the deployed
  /// rules or leave a half-deleted account behind.
  Future<DeleteAccountStatus> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return DeleteAccountStatus.error;

    try {
      // Step 1 — Confirm with Google.
      if (kIsWeb) {
        await user
            .reauthenticateWithPopup(GoogleAuthProvider())
            .timeout(const Duration(seconds: 30));
      } else {
        final credential =
            await _googleCredential().timeout(const Duration(seconds: 30));
        if (credential == null) return DeleteAccountStatus.cancelled;
        await user.reauthenticateWithCredential(credential);
      }

      // Step 2 — The server deletes everything. The free server may need
      // about a minute to wake up.
      final idToken = await user.getIdToken(true);
      final response = await _http
          .post(
            Uri.parse('${Env.httpBaseUrl}/delete_account'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        debugPrint('deleteAccount: server ${response.statusCode} ${response.body}');
        return DeleteAccountStatus.error;
      }

      // Step 3 — Sign out locally; the account is already gone.
      if (!kIsWeb) {
        try { await _googleSignIn.signOut(); } catch (_) {}
      }
      try { await _auth.signOut(); } catch (_) {}
      _profile = null;
      notifyListeners();
      return DeleteAccountStatus.success;
    } on TimeoutException {
      return DeleteAccountStatus.offline;
    } on http.ClientException {
      return DeleteAccountStatus.offline;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') return DeleteAccountStatus.offline;
      // Picked a different Google account than the signed-in one.
      if (e.code == 'user-mismatch') return DeleteAccountStatus.wrongAccount;
      debugPrint('deleteAccount FirebaseAuthException: ${e.code} ${e.message}');
      return DeleteAccountStatus.error;
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      return DeleteAccountStatus.error;
    }
  }

  Future<void> _loadOrCreateProfile(User user, {bool checkMigration = false}) async {
    if (_profileLoading) {
      await _profileLoadCompleter?.future;
      return;
    }
    _profileLoading = true;
    _profileLoadCompleter = Completer<void>();
    _needsMigrationDialog = false;

    try {
      final docRef = _db.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final localXp = PrefsService.totalXp;
        final newProfile = UserProfile(
          uid: user.uid,
          displayName: _firstNameOf(user.displayName) ?? PrefsService.playerName,
          photoUrl: user.photoURL,
          xp: 0,
          level: 1,
        );
        _profile = newProfile;
        // Cloud doc starts at 0; zero out local display for consistency.
        PrefsService.totalXp = 0;
        PrefsService.playerLevel = 1;

        if (localXp > 0) {
          // New account but has guest XP — offer migration.
          _guestXpBeforeMigration = localXp;
          _needsMigrationDialog = true;
          debugPrint('[AuthService] New account with guest XP ($localXp) — migration dialog pending');
        }

        try {
          await docRef.set(newProfile.toMap());
          debugPrint('[AuthService] ✅ Firestore document created');
        } catch (e) {
          debugPrint('[AuthService] ⚠️ Firestore write failed: $e');
        }
      } else {
        // Existing account — capture local XP before overwriting with cloud value.
        final localXp = PrefsService.totalXp;
        _profile = UserProfile.fromFirestore(doc);
        debugPrint('[AuthService] Existing account — cloud XP: ${_profile!.xp}, local XP: $localXp');

        // Only offer migration if explicitly requested (transition) or if there's a significant 
        // discrepancy while NO sync receipts are pending.
        bool hasPendingSync = PrefsService.pendingSyncReceipts.isNotEmpty;
        // Nothing to migrate without guest XP, even on a fresh sign-in.
        if (localXp > 0 &&
            (checkMigration || (!hasPendingSync && localXp > _profile!.xp + 50))) {
          _guestXpBeforeMigration = localXp;
          _needsMigrationDialog = true;
          debugPrint('[AuthService] Migration dialog needed — guest XP: $localXp, cloud XP: ${_profile!.xp}');
        }

        // Cloud wins for display regardless of migration choice.
        PrefsService.totalXp = _profile!.xp;
        PrefsService.playerLevel = _profile!.level;
        PrefsService.matchesPlayed = _profile!.matchesPlayed;
        PrefsService.tokensCapture = _profile!.tokensCapture;
        PrefsService.wins = _profile!.wins;

        // Patch missing photo URL
        if (_profile!.photoUrl == null && user.photoURL != null) {
          _profile = _profile!.copyWith(photoUrl: user.photoURL);
          try {
            await docRef.update({'photo_url': user.photoURL});
          } catch (_) {}
        }
      }

      if (_profile!.displayName.isNotEmpty) {
        PrefsService.playerName = _profile!.displayName;
      }
      PrefsService.avatarType = _profile!.avatarType;
      PrefsService.avatarIconId = _profile!.avatarIconId;
      debugPrint('[AuthService] Profile ready — name: ${_profile!.displayName}, XP: ${_profile!.xp}');
    } catch (e, stack) {
      debugPrint('[AuthService] ⚠️ _loadOrCreateProfile failed: $e\n$stack');
    } finally {
      _profileLoading = false;
      _profileLoadCompleter?.complete();
      _profileLoadCompleter = null;
    }
    notifyListeners();
  }

  /// Reloads the profile from Firestore — called by SyncQueueService after
  /// the server confirms XP was applied.
  Future<void> reloadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _loadOrCreateProfile(user);
  }

  /// Clears active_match_id in Firestore — called when a rejoin fails or the
  /// match is gone so the stale field doesn't trigger another rejoin attempt.
  Future<void> clearActiveMatchId() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).update({'active_match_id': null});
      if (_profile != null) {
        _profile = _profile!.copyWith(activeMatchId: null);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('clearActiveMatchId error: $e');
    }
  }

  /// Called by the UI after the user makes a choice in the migration dialog.
  void clearMigrationDialog() {
    _needsMigrationDialog = false;
    _guestXpBeforeMigration = 0;
    notifyListeners();
  }

  static String? _firstNameOf(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return null;
    return fullName.trim().split(RegExp(r'\s+')).first;
  }

  Future<void> updateAvatar(String type, {String? iconId}) async {
    final user = _auth.currentUser;
    if (user == null || _profile == null) return;
    _profile = _profile!.copyWith(avatarType: type, avatarIconId: iconId);
    PrefsService.avatarType = type;
    PrefsService.avatarIconId = iconId;
    notifyListeners();
    try {
      await _db.collection('users').doc(user.uid).update({
        'avatar_type': type,
        'avatar_icon_id': iconId,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('updateAvatar error: $e');
    }
  }

  /// Mirrors a finished match in the local stats shown in the UI. The
  /// Firestore profile is written only by the server: online results when
  /// the match ends, offline ones from the receipts sent to /xp_sync.
  void recordLocalMatchStats({required int captures, bool isWin = false}) {
    PrefsService.matchesPlayed = PrefsService.matchesPlayed + 1;
    PrefsService.tokensCapture = PrefsService.tokensCapture + captures;
    if (isWin) PrefsService.wins = PrefsService.wins + 1;

    if (_profile != null) {
      _profile = _profile!.copyWith(
        matchesPlayed: _profile!.matchesPlayed + 1,
        tokensCapture: _profile!.tokensCapture + captures,
        wins: isWin ? _profile!.wins + 1 : _profile!.wins,
      );
    }
    notifyListeners();
  }
}
