class Env {
  // 🛠️ Cambia esto a 'true' cuando subas el servidor a la nube
  static const bool isProduction = false;

  // 🏠 URL de desarrollo (USB / Local)
  static const String devUrl = 'ws://127.0.0.1:8080/ws';

  // ☁️ URL de producción (La que te de Railway/Render)
  static const String prodUrl = 'wss://tu-servidor-parchis.up.railway.app/ws';

  static String get serverUrl => isProduction ? prodUrl : devUrl;
}
