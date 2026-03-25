import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

  static Future<void> clear() async {
    await _prefs.clear();
  }
}
