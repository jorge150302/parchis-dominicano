import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

final socketService = SocketService.instance;

class SocketService with ChangeNotifier {
  SocketService._privateConstructor();
  static final SocketService _instance = SocketService._privateConstructor();
  static SocketService get instance => _instance;

  IOWebSocketChannel? _channel;
  bool _isConnected = false;
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();
  
  // 🔥 ESTA ES LA VARIABLE QUE FALTABA
  Map<String, dynamic>? lastGameState;

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String url) async {
    if (_isConnected) return;
    debugPrint('🔌 Conectando a WebSocket: $url');
    
    try {
      final ws = await WebSocket.connect(url).timeout(const Duration(seconds: 5));
      _channel = IOWebSocketChannel(ws);
      _isConnected = true;
      notifyListeners();
      debugPrint('✅ ¡Conectado con éxito!');

      _channel!.stream.listen(
        (message) {
          debugPrint('📥 RECIBIDO del servidor: $message');
          try {
            final data = jsonDecode(message);
            if (data is Map<String, dynamic>) {
              // 🔥 Si recibimos el estado, lo guardamos para el GameController
              if (data['event'] == 'game_state') {
                lastGameState = data['data'];
              }
              _eventController.add(data);
            }
          } catch (e) {
            debugPrint('⚠️ Error decodificando JSON: $e');
          }
        },
        onDone: () => _handleDisconnect('Servidor cerró conexión'),
        onError: (e) => _handleDisconnect('Error en stream: $e'),
      );
    } on TimeoutException {
      _handleDisconnect('Tiempo de espera agotado (Timeout)');
      rethrow;
    } catch (e) {
      _handleDisconnect('Error de red: $e');
      rethrow;
    }
  }

  void _handleDisconnect(String reason) {
    debugPrint('ℹ️ Desconectado: $reason');
    _isConnected = false;
    _channel = null;
    lastGameState = null; // Limpiamos al desconectar
    notifyListeners();
  }

  void send(String event, [Map<String, dynamic>? data]) {
    if (_channel == null || !_isConnected) return;
    final message = jsonEncode({'event': event, if (data != null) 'data': data});
    debugPrint('📤 Enviando: $message');
    _channel!.sink.add(message);
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    _channel = null;
    lastGameState = null;
    notifyListeners();
  }
}
