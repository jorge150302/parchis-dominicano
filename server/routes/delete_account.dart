import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:parchis_server/account_deletion.dart';
import 'package:parchis_server/firebase_admin.dart';

/// `POST /delete_account` with `{"id_token": ...}` from a fresh sign-in:
/// deletes the profile with all its history, then the Firebase Auth user.
/// See account_deletion.dart.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed, body: 'POST only');
  }
  if (!isAdminConfigured) {
    return _json(
      HttpStatus.serviceUnavailable,
      {'error': 'Firebase Admin not configured'},
    );
  }

  String? idToken;
  try {
    final body = jsonDecode(await context.request.body());
    idToken = (body as Map<String, dynamic>)['id_token'] as String?;
  } catch (_) {
    return _json(HttpStatus.badRequest, {'error': 'Invalid JSON'});
  }

  final now = DateTime.now();
  try {
    final outcome = await deleteAccount(
      idToken,
      now: now,
      verify: (token) async {
        try {
          final decoded = await getAdminAuth().verifyIdToken(token);
          return VerifiedToken(decoded.uid, decoded.authTime);
        } catch (_) {
          return null;
        }
      },
      deleteData: (uid) {
        final db = getAdminFirestore();
        return db.recursiveDelete(db.collection('users').doc(uid));
      },
      deleteAuthUser: (uid) async {
        // Idempotent: an already-deleted user counts as a success.
        final result = await getAdminAuth().deleteUsers([uid]);
        if (result.failureCount > 0) {
          throw StateError('Auth user $uid not deleted: ${result.errors}');
        }
      },
    );
    return switch (outcome) {
      DeletionOutcome.deleted => _json(HttpStatus.ok, {'deleted': true}),
      DeletionOutcome.invalidToken => _json(
          HttpStatus.unauthorized,
          {'error': 'Invalid or expired id_token'},
        ),
      DeletionOutcome.reauthRequired =>
        _json(HttpStatus.forbidden, {'error': 'reauth_required'}),
    };
  } catch (e, st) {
    stderr
      ..writeln('[${now.toUtc().toIso8601String()}] ERROR delete_account: $e')
      ..writeln(st);
    return _json(HttpStatus.internalServerError, {'error': 'Deletion failed'});
  }
}

Response _json(int status, Map<String, Object?> body) =>
    Response(statusCode: status, body: jsonEncode(body));
