import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/models/xp_receipt.dart';

void main() {
  final at = DateTime.utc(2026, 11, 2, 12);

  test('match receipts carry the stats the server bounds', () {
    final json = XpReceipt(
      id: 'a',
      xp: 0,
      isOnline: false,
      timestamp: at,
      isMatch: true,
      isWin: true,
      captures: 3,
    ).toJson();
    expect(json, {
      'id': 'a',
      'xp': 0,
      'is_online': false,
      'timestamp': at.toIso8601String(),
      'match': true,
      'win': true,
      'captures': 3,
    });
  });

  test('XP-only receipts (guest migration) omit match fields', () {
    final json =
        XpReceipt(id: 'm', xp: 75, isOnline: false, timestamp: at).toJson();
    expect(json.containsKey('match'), isFalse);
    expect(json.containsKey('win'), isFalse);
    expect(json.containsKey('captures'), isFalse);
  });

  test('round-trips, and old stored receipts without stats still load', () {
    final r = XpReceipt(
        id: 'a', xp: 10, isOnline: false, timestamp: at, isMatch: true, captures: 2);
    final back = xpReceiptsFromJson(xpReceiptsToJson([r])).single;
    expect(back.isMatch, isTrue);
    expect(back.captures, 2);

    final legacy = xpReceiptsFromJson(
        '[{"id":"x","xp":5,"is_online":true,"timestamp":"${at.toIso8601String()}"}]');
    expect(legacy.single.isMatch, isFalse);
    expect(legacy.single.isOnline, isTrue);
  });
}
