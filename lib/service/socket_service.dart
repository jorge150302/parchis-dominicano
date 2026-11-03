import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_info.dart';
import 'prefs_service.dart';

final socketService = SocketService.instance;

class SocketService with ChangeNotifier {
  SocketService._privateConstructor();
  static final SocketService _instance = SocketService._privateConstructor();
  static SocketService get instance => _instance;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _lastUrl;
  Timer? _reconnectTimer;
  String? _cachedIdToken;
  Timer? _tokenRefreshTimer;

  /// Messages sent while a connection is being (re)established; flushed in
  /// order once it opens so a `find_match` or `roll_dice` is not silently lost.
  final List<String> _pending = [];
  static const _maxPending = 50;

  // request_sync carries the token so the server can verify the reconnecting
  // device owns the seat.
  static const _authEvents = {'create_game', 'join_game', 'find_match', 'register_session', 'request_sync'};

  /// Supplies a fresh Firebase ID token (they expire after ~1 h). Set once at
  /// startup; used on every connect and refreshed periodically.
  Future<String?> Function()? idTokenProvider;

  void cacheIdToken(String? token) => _cachedIdToken = token;

  Future<void> _refreshIdToken() async {
    final provider = idTokenProvider;
    if (provider == null) return;
    try {
      _cachedIdToken = await provider();
    } catch (e) {
      debugPrint('⚠️ No se pudo refrescar el idToken: $e');
    }
  }
  
  // Ping/Latency
  Timer? _pingTimer;
  int _latency = 0;
  DateTime? _pingStartTime;

  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  
  Map<String, dynamic>? lastGameState;

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  int get latency => _latency;

  Future<void> connect(String url) async {
    _lastUrl = url;
    if (_isConnected || _isConnecting) return;

    _isConnecting = true;
    notifyListeners();
    debugPrint('🔌 Conectando a WebSocket: $url');
    
    try {
      await _refreshIdToken();
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;
      await channel.ready;
      // disconnect() (or a newer connect) ran while we were waiting.
      if (_channel != channel) {
        channel.sink.close();
        return;
      }

      _isConnected = true;
      _isConnecting = false;
      _reconnectTimer?.cancel();
      _startPingTimer(); // Iniciar ping al conectar
      _tokenRefreshTimer?.cancel();
      _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) => _refreshIdToken());
      notifyListeners();
      debugPrint('✅ ¡Conectado con éxito!');

      // Bound to this channel: a late onDone from a previous connection must
      // not tear down the current one.
      channel.stream.listen(
        (message) {
          if (_channel != channel) return;
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              final event = data['event'];
              
              if (event == 'game_state') {
                lastGameState = data['data'];
              } else if (event == 'pong') {
                _handlePong();
                return; // No emitir pong como evento general
              }
              
              _eventController.add(data);
            }
          } catch (e) {
            debugPrint('⚠️ Error JSON: $e');
          }
        },
        onDone: () {
          if (_channel == channel) _handleDisconnect('Servidor cerró conexión');
        },
        onError: (e) {
          if (_channel == channel) _handleDisconnect('Error en stream: $e');
        },
      );

      for (final message in _pending) {
        channel.sink.add(message);
      }
      _pending.clear();
    } catch (e) {
      _isConnecting = false;
      _handleDisconnect('Error de red: $e');
      rethrow;
    }
  }

  void _handleDisconnect(String reason) {
    debugPrint('ℹ️ Desconectado: $reason');
    _isConnected = false;
    _channel = null;
    _pingTimer?.cancel();
    _latency = 0;
    notifyListeners();
    _startReconnectionTimer();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isConnected) {
        _pingStartTime = DateTime.now();
        send('ping');
      }
    });
  }

  void _handlePong() {
    if (_pingStartTime != null) {
      _latency = DateTime.now().difference(_pingStartTime!).inMilliseconds;
      _pingStartTime = null;
      notifyListeners();
    }
  }

  void _startReconnectionTimer() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_lastUrl == null) return;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!_isConnected && !_isConnecting) {
        try {
          await connect(_lastUrl!);
          if (_isConnected) {
            timer.cancel();
            send('request_sync');
          }
        } catch (e) {
          debugPrint('❌ Fallo reconexión: $e');
        }
      } else if (_isConnected) {
        timer.cancel();
      }
    });
  }

  void send(String event, [Map<String, dynamic>? data]) {
    final waiting = !_isConnected && (_isConnecting || _lastUrl != null);
    if (!_isConnected && !waiting) return;
    if (waiting && event == 'ping') return;

    final payload = {
      'event': event,
      'clientId': PrefsService.playerId,
      'level': PrefsService.playerLevel,
      'avatarType': PrefsService.avatarType,
      'build': AppInfo.build,
      if (PrefsService.avatarIconId != null) 'avatarIconId': PrefsService.avatarIconId,
      if (_cachedIdToken != null && _authEvents.contains(event)) 'idToken': _cachedIdToken,
      'data': data,
    };
    
    final message = jsonEncode(payload);
    if (_isConnected && _channel != null) {
      _channel!.sink.add(message);
    } else if (_pending.length < _maxPending) {
      _pending.add(message);
    }
  }

  void disconnect() {
    _lastUrl = null;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _tokenRefreshTimer?.cancel();
    _pending.clear();
    _channel?.sink.close();
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
    lastGameState = null;
    notifyListeners();
  }
}
