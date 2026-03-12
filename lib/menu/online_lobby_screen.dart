import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/config/env.dart';
import 'package:frontend_parchis/service/prefs_service.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  late final TextEditingController _nameController;
  final _roomCodeController = TextEditingController();
  late final StreamSubscription _socketSubscription;
  bool _isLoading = false;
  String? _currentRoomCode;
  int? _maxPlayersInRoom;
  int _currentPlayersInRoom = 0;

  final String _serverUrl = Env.serverUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: PrefsService.playerName);
    _socketSubscription = socketService.events.listen(_handleServerEvent);
  }

  void _handleServerEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final eventName = event['event'];
    final data = event['data'];

    switch (eventName) {
      case 'game_created':
        setState(() {
          _isLoading = false;
          _currentRoomCode = data['roomCode'];
          _maxPlayersInRoom = data['maxPlayers'] ?? 2;
          _currentPlayersInRoom = 1;
        });
        PrefsService.lastRoomCode = _currentRoomCode;
        break;

      case 'game_joined':
        final String joinedCode = data['roomCode'] ?? _roomCodeController.text.trim();
        setState(() {
          _isLoading = false;
          _currentRoomCode = joinedCode;
          _maxPlayersInRoom = data['maxPlayers'];
        });
        PrefsService.lastRoomCode = joinedCode;
        
        // REGLA 1 (Backend): Salto directo por reconexión
        if (data['reconnected'] == true) {
          _navigateToGame();
        }
        break;

      case 'game_state':
        final List players = data['players'] ?? [];
        final int maxPlayers = data['maxPlayers'] ?? 2;
        final String? phase = data['phase'];
        
        setState(() {
          _currentPlayersInRoom = players.length;
          _maxPlayersInRoom = maxPlayers;
        });

        // REGLA 2: Solo navegamos si la sala está llena O si el juego ya está en marcha
        if (players.length >= maxPlayers || (phase != null && phase != 'idle' && phase != 'finished')) {
          _navigateToGame(playerCount: players.length);
        }
        break;

      case 'info':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? ''), backgroundColor: Colors.orange),
        );
        break;

      case 'error':
        setState(() {
          _isLoading = false;
          _currentRoomCode = null; // 🔄 Reseteamos para que no se vea la sala de espera si hubo error
          _maxPlayersInRoom = null;
        });
        
        final String message = data['message'] ?? '';
        String displayMessage = message;
        
        // Personalización de mensajes sin "Error:"
        if (message.toLowerCase().contains('llena') || message.toLowerCase().contains('full')) {
          displayMessage = 'No puedes unirte a esta sala, está completa.';
        } else if (message.toLowerCase().contains('no existe') || message.toLowerCase().contains('not found')) {
          displayMessage = 'La sala no existe. Verifica el código.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(displayMessage), backgroundColor: Colors.red),
        );
        break;
    }
  }

  void _navigateToGame({int? playerCount}) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushReplacementNamed(
      context,
      '/game',
      arguments: {
        'playerCount': playerCount ?? _currentPlayersInRoom,
        'roomCode': _currentRoomCode,
      }
    );
  }

  Future<void> _showPlayerCountSelection() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return _showError('Introduce tu nombre');

    final int? selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar nueva sala'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [2, 3, 4].map((n) => ListTile(
            title: Text('$n Jugadores'),
            leading: Icon(n == 2 ? Icons.group : Icons.groups, color: Colors.orangeAccent),
            onTap: () => Navigator.pop(context, n),
          )).toList(),
        ),
      ),
    );

    if (selected != null) {
      _connectAndCreate(selected);
    }
  }

  Future<void> _connectAndCreate(int maxPlayers) async {
    final name = _nameController.text.trim();
    PrefsService.playerName = name;
    setState(() => _isLoading = true);
    try {
      await socketService.connect(_serverUrl);
      socketService.send('create_game', {
        'name': name,
        'maxPlayers': maxPlayers,
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('No se pudo conectar: $e');
    }
  }

  Future<void> _connectAndJoin({String? manualCode}) async {
    final name = _nameController.text.trim();
    final code = manualCode ?? _roomCodeController.text.trim();
    
    if (name.isEmpty || code.isEmpty) return _showError('Nombre y código obligatorios');
    
    PrefsService.playerName = name;
    setState(() => _isLoading = true);
    
    try {
      await socketService.connect(_serverUrl);
      // NO seteamos _currentRoomCode aquí para no mostrar la UI de espera prematuramente
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
    final lastCode = PrefsService.lastRoomCode;

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
                      'Multijugador en Línea',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 40),

                    if (_currentRoomCode != null)
                      _buildWaitingRoom()
                    else ...[
                      // --- RECONEXIÓN RÁPIDA ---
                      if (lastCode != null && !_isLoading)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: _actionButton(
                            title: 'VOLVER A PARTIDA: $lastCode',
                            color: Colors.orange.shade700,
                            onTap: () => _connectAndJoin(manualCode: lastCode),
                          ).animate(
                            onPlay: (controller) => controller.repeat(), 
                          ).shimmer(duration: 1500.ms),
                        ),

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
                          onTap: _showPlayerCountSelection,
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
                        onTap: () => _connectAndJoin(),
                      ).animate().fadeIn(delay: 1000.ms).scale(),
                    ],

                    const SizedBox(height: 40),
                    
                    TextButton(
                      onPressed: () {
                        if (_currentRoomCode != null) {
                          socketService.disconnect();
                          setState(() {
                            _currentRoomCode = null;
                            _maxPlayersInRoom = null;
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        _currentRoomCode != null ? 'SALIR DE LA SALA' : '← Volver al Menú', 
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
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

  Widget _buildWaitingRoom() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.orangeAccent, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'ESPERANDO JUGADORES',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Text(
            _currentRoomCode ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                '$_currentPlayersInRoom / ${_maxPlayersInRoom ?? "?"}',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const LinearProgressIndicator(
            backgroundColor: Colors.white10,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 15),
          const Text(
            'El juego iniciará cuando la sala esté llena.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    ).animate().fadeIn().scale();
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
