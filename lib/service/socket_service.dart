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

  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  
  Map<String, dynamic>? lastGameState;

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

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
      _reconnectTimer?.cancel(); // Cancelar cualquier intento de reconexión si logramos conectar
      notifyListeners();
      debugPrint('✅ ¡Conectado con éxito!');

      _channel!.stream.listen(
        (message) {
          debugPrint('📥 RECIBIDO: $message');
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              if (data['event'] == 'game_state') {
                lastGameState = data['data'];
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
    notifyListeners();

    // ✅ Iniciar reconexión automática si no fue una desconexión manual
    _startReconnectionTimer();
  }

  void _startReconnectionTimer() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_lastUrl == null) return;

    debugPrint('🔄 Iniciando temporizador de reconexión...');
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isConnected && !_isConnecting) {
        debugPrint('🔄 Intentando reconectar automáticamente...');
        try {
          await connect(_lastUrl!);
          if (_isConnected) {
            timer.cancel();
            // Al reconectar, el servidor debería enviarnos el estado de nuevo
            // o nosotros podríamos pedirlo:
            send('request_sync');
          }
        } catch (e) {
          debugPrint('❌ Fallo intento de reconexión: $e');
        }
      } else if (_isConnected) {
        timer.cancel();
      }
    });
  }

  void send(String event, [Map<String, dynamic>? data]) {
    if (_channel == null || !_isConnected) {
      debugPrint('🚫 No se puede enviar "$event": No hay conexión');
      return;
    }
    
    final payload = {
      'event': event,
      'clientId': PrefsService.playerId,
      if (data != null) 'data': data,
    };
    
    final message = jsonEncode(payload);
    debugPrint('📤 Enviando: $message');
    _channel!.sink.add(message);
  }

  void disconnect() {
    _lastUrl = null; // Evitar reconexión automática si desconectamos a propósito
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
    lastGameState = null;
    notifyListeners();
  }
}
