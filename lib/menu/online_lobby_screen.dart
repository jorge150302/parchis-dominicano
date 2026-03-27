import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:frontend_parchis/service/socket_service.dart';
import 'package:frontend_parchis/config/env.dart';
import 'package:frontend_parchis/service/prefs_service.dart';
import '../config/language_provider.dart';

class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final _roomCodeController = TextEditingController();
  late final StreamSubscription _socketSubscription;
  bool _isLoading = false;
  String? _currentRoomCode;
  int? _maxPlayersInRoom;
  int _currentPlayersInRoom = 0;
  int? _lastRequestedPlayers;

  final String _serverUrl = Env.serverUrl;

  @override
  void initState() {
    super.initState();
    _socketSubscription = socketService.events.listen(_handleServerEvent);

    _roomCodeController.addListener(() {
      if (mounted) setState(() {});
    });

    if (PrefsService.lastRoomCode != null) {
      _roomCodeController.text = PrefsService.lastRoomCode!;
    }
  }

  void _handleServerEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    final eventName = event['event'];
    final data = event['data'] ?? {};

    switch (eventName) {
      case 'game_created':
      case 'game_joined':
        final String joinedCode = data['roomCode'] ?? _roomCodeController.text.trim();
        setState(() {
          _isLoading = false;
          _currentRoomCode = joinedCode;
          _maxPlayersInRoom = data['maxPlayers'];
        });
        PrefsService.lastRoomCode = joinedCode;
        if (data['reconnected'] == true) _navigateToGame(roomCode: joinedCode);
        break;

      case 'game_state':
        final List players = data['players'] ?? [];
        final int maxPlayers = data['maxPlayers'] ?? 2;
        final String? phase = data['phase'];
        final String? roomCode = data['roomCode'];

        setState(() {
          _isLoading = false;
          _currentPlayersInRoom = players.length;
          _maxPlayersInRoom = maxPlayers;
          if (_currentRoomCode == null && roomCode != null) {
            _currentRoomCode = roomCode;
            _roomCodeController.text = roomCode;
            PrefsService.lastRoomCode = roomCode;
          }
        });

        if (players.length >= maxPlayers || (phase != null && phase != 'idle' && phase != 'finished')) {
          _navigateToGame(playerCount: players.length, roomCode: roomCode);
        }
        break;

      case 'error':
        setState(() => _isLoading = false);
        final String message = data['message'] ?? '';
        final String? code = data['code'];

        if (code == 'MATCH_NOT_FOUND') {
          _showMatchNotFoundOptions();
        } else {
          _showError(message);
        }
        break;
    }
  }

  void _navigateToGame({int? playerCount, String? roomCode}) {
    if (!mounted) return;
    final targetRoomCode = roomCode ?? _currentRoomCode ?? _roomCodeController.text.trim();
    if (targetRoomCode.isEmpty) return;

    setState(() => _isLoading = false);
    Navigator.pushReplacementNamed(context, '/game', arguments: {
      'playerCount': playerCount ?? _currentPlayersInRoom,
      'roomCode': targetRoomCode,
    });
  }

  void _showMatchNotFoundOptions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.translate('no_matches_found')),
        content: Text(context.translate('no_matches_content')),
        actions: [
          Column(
            children: [
              _dialogButton(
                icon: Icons.videogame_asset,
                title: context.translate('play_offline'),
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/players');
                },
              ),
              const SizedBox(height: 8),
              _dialogButton(
                icon: Icons.add_box,
                title: context.translate('create_my_room'),
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _connectAndCreate(_lastRequestedPlayers ?? 4, true);
                },
              ),
              const SizedBox(height: 8),
              _dialogButton(
                icon: Icons.arrow_back,
                title: context.translate('back_to_menu'),
                color: Colors.grey,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamedAndRemoveUntil('/menu', (route) => false);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dialogButton({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(title),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
      ),
    );
  }

  Future<void> _handleQuickMatch() async {
    final int? selected = await _showPlayerCountDialog(context.translate('search_quick_match'));
    if (selected != null) {
      _lastRequestedPlayers = selected;
      setState(() { _isLoading = true; _currentRoomCode = null; });
      try {
        await socketService.connect(_serverUrl);
        socketService.send('find_match', {'name': PrefsService.playerName, 'maxPlayers': selected});
      } catch (e) {
        setState(() => _isLoading = false);
        _showError('No se pudo conectar: $e');
      }
    }
  }

  Future<void> _handleCreateGame() async {
    bool isPublic = true;
    int? maxPlayers = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.brown.shade900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.orange)),
          title: Text(context.translate('configure_room'), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[2, 3, 4].map((n) => ListTile(
                title: Text('$n ${context.translate('players_count')}', style: const TextStyle(color: Colors.white)),
                leading: Icon(n == 2 ? Icons.group : Icons.groups, color: Colors.orangeAccent),
                onTap: () => Navigator.pop(context, n),
              )),
              const Divider(color: Colors.white24),
              SwitchListTile(
                title: Text(context.translate('public_room'), style: const TextStyle(fontSize: 14, color: Colors.white)),
                subtitle: Text(context.translate('public_room_subtitle'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                value: isPublic,
                activeColor: Colors.orange,
                onChanged: (v) => setDialogState(() => isPublic = v),
              ),
            ],
          ),
        ),
      ),
    );

    if (maxPlayers != null) {
      _connectAndCreate(maxPlayers, isPublic);
    }
  }

  Future<void> _connectAndCreate(int maxPlayers, bool isPublic) async {
    setState(() => _isLoading = true);
    try {
      await socketService.connect(_serverUrl);
      socketService.send('create_game', {'name': PrefsService.playerName, 'maxPlayers': maxPlayers, 'isPublic': isPublic});
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('No se pudo conectar: $e');
    }
  }

  Future<int?> _showPlayerCountDialog(String title) {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        title: Text(title, style: const TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [2, 3, 4].map((n) => ListTile(
            title: Text('$n ${context.translate('players_count')}', style: const TextStyle(color: Colors.white)),
            leading: Icon(n == 2 ? Icons.group : Icons.groups, color: Colors.orangeAccent),
            onTap: () => Navigator.pop(context, n),
          )).toList(),
        ),
      ),
    );
  }

  Future<void> _connectAndJoin({String? manualCode}) async {
    final code = manualCode ?? _roomCodeController.text.trim();
    if (code.isEmpty) return _showError(context.translate('name_code_error'));
    
    if (manualCode != null) _roomCodeController.text = manualCode;
    setState(() => _isLoading = true);
    try {
      await socketService.connect(_serverUrl);
      socketService.send('join_game', {'roomCode': code, 'name': PrefsService.playerName});
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
          Positioned.fill(child: Image.asset('assets/images/menu_background.png', fit: BoxFit.cover)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('PARCHÉ', textAlign: TextAlign.center, style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4)).animate().fadeIn().slideY(begin: -0.3),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(context.translate('multiplayer_online'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 40),

                    if (_currentRoomCode != null)
                      _buildWaitingRoom()
                    else ...[
                      if (_isLoading)
                        const CircularProgressIndicator(color: Colors.orangeAccent)
                      else ...[
                        if (lastCode != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _lobbyCard(
                              icon: Icons.history,
                              title: context.translate('rejoin_match'),
                              subtitle: lastCode,
                              color: Colors.orange.shade700,
                              onTap: () => _connectAndJoin(manualCode: lastCode),
                            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                          ),

                        _lobbyCard(
                          icon: Icons.bolt,
                          title: context.translate('quick_match'),
                          subtitle: context.translate('quick_match_subtitle'),
                          color: Colors.blueAccent,
                          onTap: _handleQuickMatch,
                        ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),

                        const SizedBox(height: 20),

                        _lobbyCard(
                          icon: Icons.group_add,
                          title: context.translate('play_with_friends'),
                          subtitle: context.translate('play_with_friends_subtitle'),
                          color: Colors.green.shade600,
                          onTap: _showPrivateOptions,
                        ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.2),
                      ],
                    ],

                    const SizedBox(height: 40),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (_currentRoomCode != null) { socketService.disconnect(); setState(() { _currentRoomCode = null; }); }
                          else { Navigator.pop(context); }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: Text(
                          _currentRoomCode != null ? context.translate('leave_room') : context.translate('back'), 
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                        ),
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

  void _showPrivateOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.brown.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.orangeAccent, width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text(context.translate('play_with_friends'), style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                _actionButton(
                  title: context.translate('create_new_room'),
                  color: Colors.green.shade600,
                  onTap: () { Navigator.pop(context); _handleCreateGame(); },
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 20),
                _customTextField(controller: _roomCodeController, hint: context.translate('private_code'), icon: Icons.vpn_key, isCode: true),
                const SizedBox(height: 15),
                _actionButton(
                  title: context.translate('join_by_code'),
                  color: Colors.orange.shade800,
                  onTap: () { Navigator.pop(context); _connectAndJoin(); },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lobbyCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 25, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 28)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.orangeAccent, width: 2)),
      child: Column(
        children: [
          Text(context.translate('waiting_room'), style: const TextStyle(color: Colors.orangeAccent, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Text(_currentRoomCode ?? '', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person, color: Colors.white70),
              const SizedBox(width: 8),
              Text('$_currentPlayersInRoom / ${_maxPlayersInRoom ?? "?"}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          const LinearProgressIndicator(backgroundColor: Colors.white10, color: Colors.orangeAccent),
          const SizedBox(height: 15),
          Text(context.translate('waiting_room_subtitle'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic)),
        ],
      ),
    ).animate().fadeIn().scale();
  }

  Widget _customTextField({required TextEditingController controller, required String hint, required IconData icon, bool isCode = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))]),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        textCapitalization: isCode ? TextCapitalization.characters : TextCapitalization.words,
        style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(prefixIcon: Padding(padding: const EdgeInsets.only(left: 15), child: Icon(icon, color: Colors.orangeAccent)), hintText: hint, hintStyle: const TextStyle(color: Colors.black38), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 18)),
      ),
    );
  }

  Widget _actionButton({required String title, required Color color, Color textColor = Colors.white, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))]),
        child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    _socketSubscription.cancel();
    super.dispose();
  }
}
