import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/config/env.dart'; // ✅ Importamos Env

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  late final StreamSubscription _socketSubscription;
  bool _isLoading = false;
  String? _currentRoomCode;

  // 🔌 URL dinámica desde el archivo de configuración
  final String _serverUrl = Env.serverUrl;

  @override
  void initState() {
    super.initState();
    _socketSubscription = socketService.events.listen(_handleServerEvent);
  }

  void _handleServerEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    final eventName = event['event'];
    final data = event['data'];

    switch (eventName) {
      case 'game_created':
        _currentRoomCode = data['roomCode'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Sala creada! Código: $_currentRoomCode'),
            backgroundColor: Colors.green,
          ),
        );
        break;
      case 'game_joined':
        _currentRoomCode ??= data['roomCode'] ?? _roomCodeController.text.trim();
        break;
      case 'game_state':
        final List players = data['players'];
        Navigator.pushReplacementNamed(
          context,
          '/game',
          arguments: {
            'playerCount': players.length,
            'roomCode': _currentRoomCode,
          }
        );
        break;
      case 'error':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${data['message']}'), backgroundColor: Colors.red),
        );
        break;
    }
  }

  Future<void> _connectAndCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return _showError('Introduce tu nombre');
    setState(() => _isLoading = true);
    try {
      await socketService.connect(_serverUrl);
      socketService.send('create_game', {'name': name});
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('No se pudo conectar: $e');
    }
  }

  Future<void> _connectAndJoin() async {
    final name = _nameController.text.trim();
    final code = _roomCodeController.text.trim();
    if (name.isEmpty || code.isEmpty) return _showError('Nombre y código obligatorios');
    setState(() => _isLoading = true);
    try {
      await socketService.connect(_serverUrl);
      _currentRoomCode = code;
      socketService.send('join_game', {'roomCode': code, 'name': name});
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error de conexión: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/menu_background.png', fit: BoxFit.cover),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'PARCHÉ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                        shadows: [Shadow(blurRadius: 12, color: Colors.black54, offset: Offset(2, 3))],
                      ),
                    ).animate().fadeIn().slideY(begin: -0.3),

                    const SizedBox(height: 10),
                    const Text(
                      'Configuración de partida online',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 50),

                    _customTextField(
                      controller: _nameController,
                      hint: 'TU NOMBRE',
                      icon: Icons.person,
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),

                    const SizedBox(height: 30),

                    if (_isLoading)
                      const CircularProgressIndicator(color: Colors.orangeAccent)
                    else
                      _actionButton(
                        title: 'CREAR NUEVA SALA',
                        color: Colors.green.shade600,
                        onTap: _connectAndCreate,
                      ).animate().fadeIn(delay: 600.ms).scale(),

                    const SizedBox(height: 40),
                    const Divider(color: Colors.white38, thickness: 1.5, indent: 50, endIndent: 50),
                    const SizedBox(height: 40),

                    _customTextField(
                      controller: _roomCodeController,
                      hint: 'CÓDIGO DE SALA',
                      icon: Icons.vpn_key,
                      isCode: true,
                    ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2),

                    const SizedBox(height: 20),

                    _actionButton(
                      title: 'UNIRSE A PARTIDA',
                      color: Colors.blueAccent,
                      onTap: _connectAndJoin,
                    ).animate().fadeIn(delay: 1000.ms).scale(),

                    const SizedBox(height: 40),
                    
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('← Volver al Menú', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isCode = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textCapitalization: isCode ? TextCapitalization.characters : TextCapitalization.words,
        style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Icon(icon, color: Colors.orangeAccent),
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _actionButton({required String title, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    _socketSubscription.cancel();
    super.dispose();
  }
}
