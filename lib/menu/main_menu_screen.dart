import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🌄 FONDO FULLSCREEN
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Image.asset(
                  'assets/images/menu_background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),

            // 🎮 CONTENIDO CENTRADO
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🧩 TITULO
                    const Text(
                      'PARCHÉ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black54,
                            offset: Offset(2, 3),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 700.ms)
                        .scale(begin: const Offset(0.8, 0.8))
                        .slideY(begin: -0.3),

                    const SizedBox(height: 12),

                    const Text(
                      'Seleccionar modalidad de juego',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black38,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: -0.1),

                    const SizedBox(height: 70),

                    // 🔵 BOTÓN SIN CONEXIÓN
                    _MenuButton(
                      icon: Icons.people_alt_rounded,
                      title: 'Sin conexión',
                      subtitle: 'Juega cerca de ti',
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.pushNamed(context, '/players');
                      },
                    )
                        .animate()
                        .fadeIn(delay: 600.ms)
                        .slideX(begin: -0.4)
                        .scale(begin: const Offset(0.95, 0.95)),

                    const SizedBox(height: 28),

                    // 🟢 BOTÓN EN LÍNEA
                    _MenuButton(
                      icon: Icons.public,
                      title: 'En línea',
                      subtitle: 'Juega a distancia',
                      color: Colors.green,
                      onTap: () {
                        Navigator.pushNamed(context, '/online_lobby');
                      },
                    )
                        .animate()
                        .fadeIn(delay: 900.ms)
                        .slideX(begin: 0.4)
                        .scale(begin: const Offset(0.95, 0.95)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 22,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
