import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
// import 'package:firebase_remote_config/firebase_remote_config.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  // Versión actual de la app (Hardcoded aquí o leída de pubspec)
  late String currentVersion;
  
  // Valores remotos (Mockeados por ahora)
  String minRequiredVersion = '1.0.0';
  bool adsEnabled = true;
  int rewardXpMultiplier = 2;
  String updateUrl = 'https://play.google.com/store/apps/details?id=com.tu.juego';

  Future<void> init() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;

    try {
      // Aquí irá la lógica real de Firebase Remote Config en el futuro
      /*
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();
      
      minRequiredVersion = remoteConfig.getString('min_required_version');
      adsEnabled = remoteConfig.getBool('ads_enabled');
      rewardXpMultiplier = remoteConfig.getInt('reward_xp_multiplier');
      updateUrl = remoteConfig.getString('update_url');
      */
    } catch (e) {
      debugPrint('Error al cargar Remote Config: \$e');
    }
  }

  /// Compara si la versión actual cumple con la mínima requerida.
  /// Retorna true si debe actualizar obligatoriamente.
  bool shouldUpdate() {
    try {
      final current = _parseVersion(currentVersion);
      final required = _parseVersion(minRequiredVersion);
      
      for (int i = 0; i < 3; i++) {
        if (current[i] < required[i]) return true;
        if (current[i] > required[i]) return false;
      }
    } catch (e) {
      debugPrint('Error al comparar versiones: \$e');
    }
    return false;
  }

  List<int> _parseVersion(String v) {
    return v.split('.').map((e) => int.parse(e)).toList();
  }
}
