import 'package:parchis_server/account_deletion.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);

  /// Runs [deleteAccount] with a token for 'u1' signed in [signedInAgo]
  /// before [now] (null: the token doesn't verify), logging the steps.
  Future<(DeletionOutcome, List<String>)> run(
    String? idToken, {
    Duration? signedInAgo = Duration.zero,
  }) async {
    final steps = <String>[];
    final outcome = await deleteAccount(
      idToken,
      now: now,
      verify: (t) async => signedInAgo == null
          ? null
          : VerifiedToken('u1', now.subtract(signedInAgo)),
      deleteData: (uid) async => steps.add('data $uid'),
      deleteAuthUser: (uid) async => steps.add('auth $uid'),
    );
    return (outcome, steps);
  }

  test('a fresh sign-in deletes the data, then the auth user', () async {
    final (outcome, steps) =
        await run('token', signedInAgo: const Duration(minutes: 1));
    expect(outcome, DeletionOutcome.deleted);
    expect(steps, ['data u1', 'auth u1']);
  });

  test('a sign-in older than 5 minutes must re-authenticate first', () async {
    final (outcome, steps) =
        await run('token', signedInAgo: const Duration(minutes: 6));
    expect(outcome, DeletionOutcome.reauthRequired);
    expect(steps, isEmpty, reason: 'nothing deleted');
  });

  test('a missing or invalid token deletes nothing', () async {
    for (final token in [null, '']) {
      final (outcome, steps) = await run(token);
      expect(outcome, DeletionOutcome.invalidToken);
      expect(steps, isEmpty);
    }
    final (outcome, steps) = await run('forged', signedInAgo: null);
    expect(outcome, DeletionOutcome.invalidToken);
    expect(steps, isEmpty);
  });

  test('if the data fails to delete, the auth user stays (a retry can finish)',
      () async {
    var authDeleted = false;
    await expectLater(
      deleteAccount(
        'token',
        now: now,
        verify: (_) async => VerifiedToken('u1', now),
        deleteData: (_) async => throw StateError('firestore down'),
        deleteAuthUser: (_) async => authDeleted = true,
      ),
      throwsStateError,
    );
    expect(authDeleted, isFalse);
  });
}
