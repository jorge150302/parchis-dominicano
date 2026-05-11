import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../game/logic/level_manager.dart';
import '../models/xp_receipt.dart';
import 'auth_service.dart';
import 'prefs_service.dart';

class SyncQueueService extends ChangeNotifier {
  static const double offlineXpRatio = 0.50;

  static const _easyCap   = 150;
  static const _mediumCap = 300;
  static const _hardCap   = 500;

  static int dailyCapForDifficulty(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy:   return _easyCap;
      case GameDifficulty.medium: return _mediumCap;
      case GameDifficulty.hard:   return _hardCap;
    }
  }

  final AuthService _authService;

  SyncQueueService(this._authService) {
    _authService.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_authService.isSignedIn) {
      if (_authService.needsSignupBonus) {
        _enqueueSignupBonus();
      }
      _attemptSync();
    }
  }

  bool get hasPendingReceipts => PrefsService.pendingSyncReceipts.isNotEmpty;
  bool get isSyncing => _isSyncing;

  int todayXpForDifficulty(GameDifficulty d) {
    switch (d) {
      case GameDifficulty.easy:   return PrefsService.todayEasyXp;
      case GameDifficulty.medium: return PrefsService.todayMediumXp;
      case GameDifficulty.hard:   return PrefsService.todayHardXp;
    }
  }

  bool isDailyCapped(GameDifficulty difficulty) =>
      todayXpForDifficulty(difficulty) >= dailyCapForDifficulty(difficulty);

  /// Awards XP after a match. Returns the actual XP added to the local total.
  /// [rawXp] is the full unmodified XP value for an online win.
  int awardMatchXp({
    required int rawXp,
    required bool isOnline,
    GameDifficulty difficulty = GameDifficulty.medium,
  }) {
    _resetDailyCounterIfNeeded();

    if (isOnline) {
      _applyLocalXp(rawXp);
      _enqueue(XpReceipt(
        id: _receiptId(),
        xp: rawXp,
        isOnline: true,
        timestamp: DateTime.now(),
      ));
      _attemptSync();
      return rawXp;
    }

    final cap = dailyCapForDifficulty(difficulty);
    final offlineXp = (rawXp * offlineXpRatio).floor();
    if (offlineXp == 0 || isDailyCapped(difficulty)) return 0;

    final todayEarned = todayXpForDifficulty(difficulty);
    final remaining = cap - todayEarned;
    final awarded = offlineXp.clamp(0, remaining);
    if (awarded <= 0) return 0;

    _enqueue(XpReceipt(
      id: _receiptId(),
      xp: awarded,
      isOnline: false,
      timestamp: DateTime.now(),
    ));
    _applyLocalXp(awarded);
    _incrementDailyXp(difficulty, awarded);

    if (_authService.isSignedIn) _attemptSync();

    notifyListeners();
    return awarded;
  }

  Future<void> syncNow() => _attemptSync();

  /// Submits guest XP as server receipts, capped at 500 XP total.
  /// Called when the user chooses "Keep my progress" in the migration dialog.
  void enqueueGuestMigration(int localXp) {
    const maxMigrationXp = 500;
    const maxPerReceipt = 75;
    final toMigrate = localXp.clamp(0, maxMigrationXp);
    int remaining = toMigrate;
    final now = DateTime.now();
    var i = 0;
    while (remaining > 0) {
      final chunk = remaining.clamp(0, maxPerReceipt);
      _enqueue(XpReceipt(
        id: 'migration_${now.microsecondsSinceEpoch}_$i',
        xp: chunk,
        isOnline: false,
        timestamp: now,
      ));
      remaining -= chunk;
      i++;
    }
    _applyLocalXp(toMigrate);
    debugPrint('[SyncQueue] Guest migration enqueued: $toMigrate XP in $i receipts');
    if (_authService.isSignedIn) _attemptSync();
  }

  bool _isSyncing = false;

  // ── private helpers ──────────────────────────────────────────────────────

  void _enqueueSignupBonus() {
    if (PrefsService.signupBonusClaimed) return;
    const bonusXp = 50;
    _enqueue(XpReceipt(
      id: 'signup_${_authService.firebaseUser!.uid}',
      xp: bonusXp,
      isOnline: false,
      timestamp: DateTime.now(),
    ));
    _applyLocalXp(bonusXp);
    PrefsService.signupBonusClaimed = true;
    debugPrint('[SyncQueue] Signup bonus enqueued (+$bonusXp XP)');
  }

  void _applyLocalXp(int xp) {
    final newTotal = PrefsService.totalXp + xp;
    PrefsService.totalXp = newTotal;
    PrefsService.playerLevel = LevelManager.calculateLevel(newTotal);
    notifyListeners();
  }

  void _enqueue(XpReceipt receipt) {
    final list = PrefsService.pendingSyncReceipts;
    list.add(receipt);
    PrefsService.pendingSyncReceipts = list;
  }

  void _incrementDailyXp(GameDifficulty d, int xp) {
    switch (d) {
      case GameDifficulty.easy:   PrefsService.todayEasyXp   = PrefsService.todayEasyXp   + xp;
      case GameDifficulty.medium: PrefsService.todayMediumXp = PrefsService.todayMediumXp + xp;
      case GameDifficulty.hard:   PrefsService.todayHardXp   = PrefsService.todayHardXp   + xp;
    }
  }

  void _resetDailyCounterIfNeeded() {
    final lastReset = PrefsService.lastDailyReset;
    final now = DateTime.now();
    if (lastReset == null || !_isSameDay(lastReset, now)) {
      PrefsService.todayEasyXp   = 0;
      PrefsService.todayMediumXp = 0;
      PrefsService.todayHardXp   = 0;
      PrefsService.lastDailyReset = now;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _receiptId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _attemptSync() async {
    if (_isSyncing || !_authService.isSignedIn) return;
    final receipts = List<XpReceipt>.from(PrefsService.pendingSyncReceipts);
    if (receipts.isEmpty) return;

    _isSyncing = true;
    notifyListeners();
    // Clear before the async call to avoid re-sending receipts from re-entrant triggers.
    PrefsService.pendingSyncReceipts = [];

    try {
      final idToken = await _authService.firebaseUser?.getIdToken();
      if (idToken == null) {
        final newer = PrefsService.pendingSyncReceipts;
        PrefsService.pendingSyncReceipts = [...receipts, ...newer];
        return;
      }

      final url = Uri.parse('${Env.httpBaseUrl}/xp_sync');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'receipts': receipts.map((r) => r.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('[SyncQueue] ✅ XP synced: ${response.body}');
        await _authService.reloadProfile();
        notifyListeners();
      } else {
        debugPrint('[SyncQueue] ⚠️ Server error ${response.statusCode}: ${response.body}');
        final newer = PrefsService.pendingSyncReceipts;
        PrefsService.pendingSyncReceipts = [...receipts, ...newer];
      }
    } catch (e) {
      debugPrint('[SyncQueue] ⚠️ Sync failed: $e');
      final newer = PrefsService.pendingSyncReceipts;
      PrefsService.pendingSyncReceipts = [...receipts, ...newer];
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
