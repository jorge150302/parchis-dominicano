import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_profile.dart';
import 'network_checker.dart';
import 'prefs_service.dart';

enum SignInStatus { success, offline, error, cancelled }

enum SignOutStatus { success, offline }

enum DeleteAccountStatus { success, offline, error, cancelled }

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  UserProfile? _profile;
  bool _needsSignupBonus = false;
  bool _needsMigrationDialog = false;
  int _guestXpBeforeMigration = 0;
  bool _profileLoading = false;
  Completer<void>? _profileLoadCompleter;
  bool _wasSignedIn = false;

  UserProfile? get profile => _profile;
  bool get needsSignupBonus => _needsSignupBonus;
  bool get needsMigrationDialog => _needsMigrationDialog;
  int get guestXpBeforeMigration => _guestXpBeforeMigration;
  bool get isSignedIn => _auth.currentUser != null;
  User? get firebaseUser => _auth.currentUser;

  AuthService() {
    _wasSignedIn = _auth.currentUser != null;
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user != null) {
      if (!_wasSignedIn) {
        // Actual sign-in transition — discard any guest XP receipts so they
        // are not synced to the cloud as if they were earned while authenticated.
        PrefsService.pendingSyncReceipts = [];
        debugPrint('[AuthService] Guest receipts cleared on sign-in');
      }
      _wasSignedIn = true;
      await _loadOrCreateProfile(user);
    } else {
      _wasSignedIn = false;
      _profile = null;
      notifyListeners();
    }
  }

  Future<SignInStatus> signInWithGoogle() async {
    final connected = await NetworkChecker.hasConnection();
    if (!connected) return SignInStatus.offline;

    try {
      final User? user;
      if (kIsWeb) {
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        user = result.user;
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return SignInStatus.cancelled;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        user = (await _auth.signInWithCredential(credential)).user;
      }
      if (user == null) return SignInStatus.error;
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
  Future<DeleteAccountStatus> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return DeleteAccountStatus.error;

    try {
      // Step 1 — Re-authenticate (Firebase requires this before user.delete())
      if (kIsWeb) {
        await user
            .reauthenticateWithPopup(GoogleAuthProvider())
            .timeout(const Duration(seconds: 30));
      } else {
        final googleUser = await _googleSignIn
            .signIn()
            .timeout(const Duration(seconds: 30));
        if (googleUser == null) return DeleteAccountStatus.cancelled;
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // Step 2 — Delete Firestore document
      await _db
          .collection('users')
          .doc(user.uid)
          .delete()
          .timeout(const Duration(seconds: 15));

      // Step 3 — Delete Firebase Auth user
      await user.delete().timeout(const Duration(seconds: 15));

      // Step 4 — Sign out (local cleanup only — account already gone server-side)
      if (!kIsWeb) {
        try { await _googleSignIn.signOut(); } catch (_) {}
      }
      try { await _auth.signOut(); } catch (_) {}

      // Step 5 — Clear in-memory state LAST (server confirmed, safe to wipe)
      _profile = null;
      notifyListeners();

      return DeleteAccountStatus.success;
    } on TimeoutException {
      return DeleteAccountStatus.offline;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') return DeleteAccountStatus.offline;
      debugPrint('deleteAccount FirebaseAuthException: ${e.code} ${e.message}');
      return DeleteAccountStatus.error;
    } on FirebaseException catch (e) {
      if (e.code == 'network-request-failed' || e.code == 'unavailable') {
        return DeleteAccountStatus.offline;
      }
      debugPrint('deleteAccount FirebaseException: ${e.code} ${e.message}');
      return DeleteAccountStatus.error;
    } catch (e) {
      debugPrint('deleteAccount error: $e');
      return DeleteAccountStatus.error;
    }
  }

  Future<void> _loadOrCreateProfile(User user) async {
    if (_profileLoading) {
      await _profileLoadCompleter?.future;
      return;
    }
    _profileLoading = true;
    _profileLoadCompleter = Completer<void>();
    _needsSignupBonus = false;
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
          // New account but has guest XP — offer migration instead of signup bonus.
          _guestXpBeforeMigration = localXp;
          _needsMigrationDialog = true;
          debugPrint('[AuthService] New account with guest XP ($localXp) — migration dialog pending');
        } else {
          _needsSignupBonus = true;
          debugPrint('[AuthService] New account — XP=0, signup bonus pending via server');
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

        // Offline progress exceeds cloud — offer migration every time this happens.
        if (localXp > _profile!.xp && localXp > 0) {
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

  /// Called by the UI after the user makes a choice in the migration dialog.
  void clearMigrationDialog() {
    _needsMigrationDialog = false;
    _guestXpBeforeMigration = 0;
    PrefsService.signupBonusClaimed = true;
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

  Future<void> incrementWins() async {
    final user = _auth.currentUser;
    if (user == null) return;
    PrefsService.wins = PrefsService.wins + 1;
    try {
      await _db.collection('users').doc(user.uid).update({
        'wins': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });
      await _loadOrCreateProfile(user);
    } catch (e) {
      debugPrint('incrementWins error: $e');
    }
  }

  /// Records match completion: increments local stats always, syncs to
  /// Firestore if signed in. [isWin] triggers a win increment for offline
  /// games (online wins are already handled by [incrementWins]).
  Future<void> updateMatchStats({
    required int captures,
    bool isWin = false,
    bool isOnline = false,
  }) async {
    PrefsService.matchesPlayed = PrefsService.matchesPlayed + 1;
    PrefsService.tokensCapture = PrefsService.tokensCapture + captures;
    if (isWin && !isOnline) PrefsService.wins = PrefsService.wins + 1;

    if (_profile != null) {
      _profile = _profile!.copyWith(
        matchesPlayed: _profile!.matchesPlayed + 1,
        tokensCapture: _profile!.tokensCapture + captures,
        wins: (isWin && !isOnline) ? _profile!.wins + 1 : _profile!.wins,
      );
      notifyListeners();
    }

    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final updates = <String, dynamic>{
        'matches_played': FieldValue.increment(1),
        'tokens_capture': FieldValue.increment(captures),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (isWin && !isOnline) updates['wins'] = FieldValue.increment(1);
      await _db.collection('users').doc(user.uid).update(updates);
    } catch (e) {
      debugPrint('updateMatchStats error: $e');
    }
  }
}
