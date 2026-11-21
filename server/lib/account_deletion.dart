/// Account deletion for `POST /delete_account`.
///
/// The server deletes the account, not the app: it holds admin rights, so
/// the profile, its server-written history and the Firebase Auth user go
/// in one place, without depending on the Firestore rules deployed to the
/// project or leaving a half-deleted account when one client step fails.
library;

/// How recently the user must have signed in (re-authenticated) for the
/// token to delete the account: a token leaked from an old session can't.
const maxDeletionAuthAge = Duration(minutes: 5);

/// The parts of a verified Firebase ID token this needs.
class VerifiedToken {
  /// A token of [uid], who last signed in at [authTime].
  const VerifiedToken(this.uid, this.authTime);

  /// The account the token belongs to.
  final String uid;

  /// When the user last signed in (the token's `auth_time`).
  final DateTime authTime;
}

/// What [deleteAccount] did.
enum DeletionOutcome {
  /// The profile, its history and the auth user are gone.
  deleted,

  /// Missing, invalid or expired token.
  invalidToken,

  /// Valid token, but the last sign-in is older than [maxDeletionAuthAge].
  reauthRequired,
}

/// Deletes the account [idToken] belongs to. The data goes first: if the
/// Auth user then fails to delete, the client can retry with a fresh token
/// and both steps simply run again.
Future<DeletionOutcome> deleteAccount(
  String? idToken, {
  required Future<VerifiedToken?> Function(String idToken) verify,
  required Future<void> Function(String uid) deleteData,
  required Future<void> Function(String uid) deleteAuthUser,
  required DateTime now,
}) async {
  if (idToken == null || idToken.isEmpty) return DeletionOutcome.invalidToken;
  final token = await verify(idToken);
  if (token == null) return DeletionOutcome.invalidToken;
  if (now.difference(token.authTime) > maxDeletionAuthAge) {
    return DeletionOutcome.reauthRequired;
  }
  await deleteData(token.uid);
  await deleteAuthUser(token.uid);
  return DeletionOutcome.deleted;
}
