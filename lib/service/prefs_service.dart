import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/xp_receipt.dart';

enum GameSpeed { normal, fast }

class PrefsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 🆔 ID del Jugador
  static String get playerId {
    String? id = _prefs.getString('player_id');
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString('player_id', id);
    }
    return id;
  }

  // 👤 Nombre
  static String get playerName => _prefs.getString('player_name') ?? '';
  static set playerName(String name) => _prefs.setString('player_name', name);

  // ✨ Tutorial
  static bool get isFirstTime => _prefs.getBool('is_first_time') ?? true;
  static set isFirstTime(bool value) => _prefs.setBool('is_first_time', value);

  // 🏠 Sala (Online)
  static String? get lastRoomCode => _prefs.getString('last_room_code');
  static set lastRoomCode(String? code) {
    if (code == null) {
      _prefs.remove('last_room_code');
    } else {
      _prefs.setString('last_room_code', code);
    }
  }

  // 💾 Partida Guardada (Offline)
  static String? get savedLocalGame => _prefs.getString('saved_local_game');
  static set savedLocalGame(String? json) {
    if (json == null) {
      _prefs.remove('saved_local_game');
    } else {
      _prefs.setString('saved_local_game', json);
    }
  }

  static bool get hasSavedGame => _prefs.containsKey('saved_local_game');

  // 🌐 Idioma
  static bool get hasLanguagePreference => _prefs.containsKey('language_code');
  static String get languageCode => _prefs.getString('language_code') ?? 'es';
  static Future<void> setLanguage(String code) => _prefs.setString('language_code', code);

  // 🔊 Ajustes de Audio y Vibración
  static bool get soundEnabled => _prefs.getBool('sound_enabled') ?? true;
  static set soundEnabled(bool value) => _prefs.setBool('sound_enabled', value);

  static bool get vibrationEnabled => _prefs.getBool('vibration_enabled') ?? true;
  static set vibrationEnabled(bool value) => _prefs.setBool('vibration_enabled', value);

  // ⚡ Velocidad de Juego
  static GameSpeed get gameSpeed {
    final index = _prefs.getInt('game_speed') ?? 0;
    return GameSpeed.values[index];
  }
  static set gameSpeed(GameSpeed speed) => _prefs.setInt('game_speed', speed.index);

  // 🤖 Selección Automática
  static bool get autoMoveEnabled => _prefs.getBool('auto_move_enabled') ?? true;
  static set autoMoveEnabled(bool value) => _prefs.setBool('auto_move_enabled', value);

  static int get autoMoveDelayMs => _prefs.getInt('auto_move_delay_ms') ?? 600;
  static set autoMoveDelayMs(int value) => _prefs.setInt('auto_move_delay_ms', value);

  // 🎭 Avatar
  static String get avatarType => _prefs.getString('avatar_type') ?? 'google';
  static set avatarType(String value) => _prefs.setString('avatar_type', value);

  static String? get avatarIconId => _prefs.getString('avatar_icon_id');
  static set avatarIconId(String? value) {
    if (value == null) {
      _prefs.remove('avatar_icon_id');
    } else {
      _prefs.setString('avatar_icon_id', value);
    }
  }

  // 🏆 Sistema de Niveles y XP
  static int get totalXp => _prefs.getInt('total_xp') ?? 0;
  static set totalXp(int value) => _prefs.setInt('total_xp', value);

  static int get playerLevel => _prefs.getInt('player_level') ?? 1;
  static set playerLevel(int value) => _prefs.setInt('player_level', value);

  // 🎁 Sign-up bonus — one-time, reset on account deletion via PrefsService.clear()
  static bool get signupBonusClaimed => _prefs.getBool('signup_bonus_claimed') ?? false;
  static set signupBonusClaimed(bool value) => _prefs.setBool('signup_bonus_claimed', value);

  // 🚫 Moderación: Lista de bloqueados persistente
  static List<String> get blockedPlayerIds {
    String? json = _prefs.getString('blocked_players');
    if (json == null) return [];
    try {
      return List<String>.from(jsonDecode(json));
    } catch (_) {
      return [];
    }
  }

  static set blockedPlayerIds(List<String> ids) {
    _prefs.setString('blocked_players', jsonEncode(ids));
  }

  // ────────────────────────────────────────────────────────────────
  // 🔄 Sync Queue — offline XP receipts awaiting cloud validation
  // ────────────────────────────────────────────────────────────────

  static List<XpReceipt> get pendingSyncReceipts {
    final raw = _prefs.getString('pending_sync_receipts');
    if (raw == null || raw.isEmpty) return [];
    return xpReceiptsFromJson(raw);
  }

  static set pendingSyncReceipts(List<XpReceipt> receipts) =>
      _prefs.setString('pending_sync_receipts', xpReceiptsToJson(receipts));

  // 📅 Daily offline XP counter
  static int get todayOfflineXp => _prefs.getInt('today_offline_xp') ?? 0;
  static set todayOfflineXp(int value) => _prefs.setInt('today_offline_xp', value);

  static DateTime? get lastDailyReset {
    final raw = _prefs.getString('last_daily_reset');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static set lastDailyReset(DateTime? value) {
    if (value == null) {
      _prefs.remove('last_daily_reset');
    } else {
      _prefs.setString('last_daily_reset', value.toIso8601String());
    }
  }

  // 🗑️ Pending account deletion (set when Firebase auth delete fails offline)
  static bool get pendingAccountDeletion =>
      _prefs.getBool('pending_account_deletion') ?? false;
  static set pendingAccountDeletion(bool value) =>
      _prefs.setBool('pending_account_deletion', value);

  // 📊 Player Statistics (local mirror; synced to Firestore when online)
  static int get matchesPlayed => _prefs.getInt('matches_played') ?? 0;
  static set matchesPlayed(int value) => _prefs.setInt('matches_played', value);

  static int get tokensCapture => _prefs.getInt('tokens_capture') ?? 0;
  static set tokensCapture(int value) => _prefs.setInt('tokens_capture', value);

  static Future<void> clear() async {
    await _prefs.clear();
  }
}
