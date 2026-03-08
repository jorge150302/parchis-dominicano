class Env {
  // 🛠️ Cambia esto a 'true' para que todos usen la URL de ngrok
  static const bool isProduction = true; 

  // 🏠 URL de desarrollo (USB / Local)
  static const String devUrl = 'ws://127.0.0.1:8080/ws';

  // 🌍 URL de ngrok generada para la prueba real
  static const String prodUrl = 'wss://baylee-nondissolving-fredrick.ngrok-free.dev/ws';

  static String get serverUrl => isProduction ? prodUrl : devUrl;
}
