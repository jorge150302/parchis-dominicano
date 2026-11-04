/// Server endpoints, chosen at build time:
///
///   flutter run --dart-define=PARCHIS_WS_URL=ws://127.0.0.1:8080/ws
///   flutter build appbundle --dart-define=PARCHIS_WS_URL=wss://api.example.com/ws
///
/// Without a define, builds keep pointing at the current tunnel so existing
/// workflows don't break; replace [_defaultWsUrl] once real hosting exists.
class Env {
  static const String _defaultWsUrl =
      'wss://baylee-nondissolving-fredrick.ngrok-free.dev/ws';

  static const String serverUrl =
      String.fromEnvironment('PARCHIS_WS_URL', defaultValue: _defaultWsUrl);

  /// HTTP base URL derived from the WebSocket URL (strips /ws, swaps scheme).
  static String get httpBaseUrl => serverUrl
      .replaceFirst('wss://', 'https://')
      .replaceFirst('ws://', 'http://')
      .replaceFirst(RegExp(r'/ws$'), '');
}
