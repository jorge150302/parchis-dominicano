import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
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

  static const _authEvents = {'create_game', 'join_game', 'find_match', 'register_session'};

  void cacheIdToken(String? token) => _cachedIdToken = token;
  
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
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;
      
      _isConnected = true;
      _isConnecting = false;
      _reconnectTimer?.cancel();
      _startPingTimer(); // Iniciar ping al conectar
      notifyListeners();
      debugPrint('✅ ¡Conectado con éxito!');

      _channel!.stream.listen(
        (message) {
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
        onDone: () => _handleDisconnect('Servidor cerró conexión'),
        onError: (e) => _handleDisconnect('Error en stream: $e'),
      );
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
    if (_channel == null || !_isConnected) return;
    
    final payload = {
      'event': event,
      'clientId': PrefsService.playerId,
      'level': PrefsService.playerLevel,
      'avatarType': PrefsService.avatarType,
      if (PrefsService.avatarIconId != null) 'avatarIconId': PrefsService.avatarIconId,
      if (_cachedIdToken != null && _authEvents.contains(event)) 'idToken': _cachedIdToken,
      'data': data,
    };
    
    _channel!.sink.add(jsonEncode(payload));
  }

  void disconnect() {
    _lastUrl = null;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
    lastGameState = null;
    notifyListeners();
  }
}
