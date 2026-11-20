/// Server endpoints, chosen at build time:
///
///   flutter run --dart-define=PARCHIS_WS_URL=ws://127.0.0.1:8080/ws
///   flutter build appbundle --dart-define=PARCHIS_WS_URL=wss://api.example.com/ws
///
/// Without a define, builds use the hosted server on Render (free plan for
/// testing: it sleeps after 15 idle minutes and takes ~1 minute to wake;
/// the socket keeps retrying meanwhile).
class Env {
  static const String _defaultWsUrl = 'wss://parchis-dominicano.onrender.com/ws';

  static const String serverUrl =
      String.fromEnvironment('PARCHIS_WS_URL', defaultValue: _defaultWsUrl);

  /// HTTP base URL derived from the WebSocket URL (strips /ws, swaps scheme).
  static String get httpBaseUrl => serverUrl
      .replaceFirst('wss://', 'https://')
      .replaceFirst('ws://', 'http://')
      .replaceFirst(RegExp(r'/ws$'), '');
}
