import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PlayerSelectionScreen extends StatefulWidget {
  const PlayerSelectionScreen({super.key});

  @override
  State<PlayerSelectionScreen> createState() => _PlayerSelectionScreenState();
}

class _PlayerSelectionScreenState extends State<PlayerSelectionScreen> {
  int? selectedPlayers;
  bool vsAI = false;

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

                  const Text(
                    'Seleccionar cantidad de jugadores',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 15),

                  // ✅ Selector de IA pequeño y compacto
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Jugar contra IA', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
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

                  const SizedBox(height: 40),

                  _playerCard(2),
                  const SizedBox(height: 22),
                  _playerCard(3),
                  const SizedBox(height: 22),
                  _playerCard(4),

                  const SizedBox(height: 60),

                  AnimatedOpacity(
                    opacity: selectedPlayers == null ? 0.5 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton(
                      onPressed: selectedPlayers == null
                          ? null
                          : () {
                        Navigator.pushNamed(
                          context,
                          '/game',
                          arguments: {
                            'playerCount': selectedPlayers,
                            'vsAI': vsAI,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('COMENZAR JUEGO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Volver', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            Text('$players jugadores', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.2);
  }
}
