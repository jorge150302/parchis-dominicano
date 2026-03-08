import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PrefsService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 🆔 ID del Jugador (UUID)
  static String get playerId {
    String? id = _prefs.getString('player_id');
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString('player_id', id);
    }
    return id;
  }

  // 👤 Nombre del Jugador
  static String get playerName => _prefs.getString('player_name') ?? '';
  static set playerName(String name) => _prefs.setString('player_name', name);

  // 🏠 Último Código de Sala (Opcional para reconexión)
  static String? get lastRoomCode => _prefs.getString('last_room_code');
  static set lastRoomCode(String? code) {
    if (code == null) {
      _prefs.remove('last_room_code');
    } else {
      _prefs.setString('last_room_code', code);
    }
  }
}
