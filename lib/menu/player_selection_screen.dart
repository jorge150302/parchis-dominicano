import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/language_provider.dart';

class PlayerSelectionScreen extends StatefulWidget {
  const PlayerSelectionScreen({super.key});

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  int? selectedPlayers;
  bool vsAI = false;
  final List<TextEditingController> _nameControllers = List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showAIInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.translate('play_vs_ai'),
          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.translate('ai_info_content'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('close'), style: const TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/menu_background.png',
                fit: BoxFit.cover,
              ),
            ),

            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                
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
                
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.translate('select_player_count'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18, 
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                
                    const SizedBox(height: 15),
                
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.translate('play_vs_ai'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _showAIInfo,
                          ),
                          const SizedBox(width: 8),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: vsAI,
                              activeColor: Colors.orangeAccent,
                              onChanged: (v) => setState(() => vsAI = v),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                
                    const SizedBox(height: 20),
                
                    _playerCard(2),
                    const SizedBox(height: 12),
                    _playerCard(3),
                    const SizedBox(height: 12),
                    _playerCard(4),
                
                    if (selectedPlayers != null) ...[
                      const SizedBox(height: 20),
                      _buildNameInputs(),
                    ],
                
                    const SizedBox(height: 30),
                
                    AnimatedOpacity(
                      opacity: selectedPlayers == null ? 0.5 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: ElevatedButton(
                        onPressed: selectedPlayers == null
                            ? null
                            : () {
                          List<String> playerNames = [];
                          int count = vsAI ? 1 : selectedPlayers!;
                          for (int i = 0; i < count; i++) {
                            String name = _nameControllers[i].text.trim();
                            if (name.isEmpty) {
                              name = '${context.translate('player')} ${i + 1}';
                            }
                            playerNames.add(name);
                          }
                          // Add AI names if applicable
                          if (vsAI) {
                            for (int i = 1; i < selectedPlayers!; i++) {
                              playerNames.add(context.translate('ai_player_name', args: {'n': '$i'}));
                            }
                          }
                
                          Navigator.pushNamed(
                            context,
                            '/game',
                            arguments: {
                              'playerCount': selectedPlayers,
                              'vsAI': vsAI,
                              'playerNames': playerNames,
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text(context.translate('start_game'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                    ).animate().fadeIn(delay: 600.ms),
                
                    const SizedBox(height: 20),
                
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        ),
                        child: Text(
                          context.translate('back'), 
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameInputs() {
    int count = vsAI ? 1 : selectedPlayers!;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: List.generate(count, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _nameControllers[i],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.translate('player_n_name', args: {'player': '${i + 1}'}),
                labelStyle: const TextStyle(color: Colors.orangeAccent),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
              ),
            ),
          );
        }),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _playerCard(int players) {
    final isSelected = selectedPlayers == players;

    Widget iconWidget() {
      if (players == 2) return Icon(Icons.group, size: 32, color: isSelected ? Colors.white : Colors.black87);
      if (players == 3) return Icon(Icons.groups, size: 32, color: isSelected ? Colors.white : Colors.black87);
      return Image.asset('assets/images/icon_4_players.png', width: 34, height: 34, color: isSelected ? Colors.white : null);
    }

    return GestureDetector(
      onTap: () => setState(() => selectedPlayers = players),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 300,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange.withOpacity(0.9) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: isSelected ? Colors.orange.withOpacity(0.6) : Colors.black26, blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget(),
            const SizedBox(width: 14),
            Text('$players ${context.translate('players_count')}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }
}
