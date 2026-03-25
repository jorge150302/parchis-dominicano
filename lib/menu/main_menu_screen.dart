import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../config/language_provider.dart';
import '../service/socket_service.dart';
import '../service/prefs_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  StreamSubscription? _socketSub;

  @override
  void initState() {
    super.initState();
    _socketSub = context.read<SocketService>().events.listen((event) {
      if (event['event'] == 'user_data_deleted') {
        _handleAccountDeleted();
      }
    });
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }

  void _handleAccountDeleted() async {
    await PrefsService.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta eliminada con éxito.'))
    );
  }

  // Lógica para reanudar la partida
  void _resumeGame() {
    final savedJson = PrefsService.savedLocalGame;
    if (savedJson != null) {
      final state = jsonDecode(savedJson);
      Navigator.pushNamed(
        context,
        '/game',
        arguments: {
          'playerCount': (state['players'] as List).length,
          'vsAI': state['vsAI'] ?? false,
          'isResume': true,
          'savedState': state,
        },
      );
    }
  }

  // Diálogo para elegir entre Continuar o Nueva Partida
  void _handleOfflineClick() {
    if (PrefsService.hasSavedGame) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.brown.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: const BorderSide(color: Colors.orangeAccent, width: 2),
          ),
          title: Text(
            context.translate('offline_mode'),
            style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Tienes una partida pendiente. ¿Qué deseas hacer?', // Podría ir en traducciones
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _resumeGame();
                    },
                    child: Text(
                      context.translate('continue_game'),
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/players');
                    },
                    child: Text(
                      'Iniciar Nueva Partida', // Podría ir en traducciones
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      Navigator.pushNamed(context, '/players');
    }
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.brown.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.orange, width: 2),
              ),
              title: Text(
                context.translate('settings'),
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.language, color: Colors.white),
                    title: Text(context.translate('language'), style: const TextStyle(color: Colors.white)),
                    trailing: DropdownButton<Language>(
                      dropdownColor: Colors.brown.shade800,
                      value: context.watch<LanguageProvider>().currentLanguage,
                      underline: const SizedBox(),
                      onChanged: (Language? newLang) {
                        if (newLang != null) {
                          context.read<LanguageProvider>().setLanguage(newLang);
                        }
                      },
                      items: [
                        DropdownMenuItem(value: Language.es, child: Text(context.translate('spanish'), style: const TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: Language.en, child: Text(context.translate('english'), style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up, color: Colors.white70),
                    title: Text(context.translate('sound'), style: const TextStyle(color: Colors.white70)),
                    value: PrefsService.soundEnabled,
                    activeColor: Colors.orange,
                    onChanged: (bool value) {
                      setDialogState(() => PrefsService.soundEnabled = value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration, color: Colors.white70),
                    title: Text(context.translate('vibration'), style: const TextStyle(color: Colors.white70)),
                    value: PrefsService.vibrationEnabled,
                    activeColor: Colors.orange,
                    onChanged: (bool value) {
                      setDialogState(() => PrefsService.vibrationEnabled = value);
                    },
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                    title: Text(context.translate('privacy_policy'), style: const TextStyle(color: Colors.white70)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/privacy');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    title: Text(context.translate('delete_account'), style: const TextStyle(color: Colors.redAccent)),
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.translate('close'), style: const TextStyle(color: Colors.orangeAccent)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        title: Text(context.translate('delete_account'), style: const TextStyle(color: Colors.red)),
        content: Text(
          context.translate('delete_account_confirm'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<SocketService>().send('delete_user_data', {
                'playerId': PrefsService.playerId,
              });
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(context.translate('confirm'), style: const TextStyle(color: Colors.white)),
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
              child: Container(
                color: Colors.black,
                child: Image.asset(
                  'assets/images/menu_background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 30),
                onPressed: () => _showSettings(context),
              ).animate().fadeIn(delay: 500.ms).scale(),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
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

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          context.translate('select_mode'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: -0.1),

                      const SizedBox(height: 70),

                      _MenuButton(
                        icon: Icons.people_alt_rounded,
                        title: context.translate('offline_mode'),
                        subtitle: context.translate('offline_subtitle'),
                        color: Colors.blueAccent,
                        onTap: _handleOfflineClick, // ✅ Cambiado a la nueva lógica
                      )
                          .animate()
                          .fadeIn(delay: 600.ms)
                          .slideX(begin: -0.4)
                          .scale(begin: const Offset(0.95, 0.95)),
                      const SizedBox(height: 28),
                      _MenuButton(
                        icon: Icons.public,
                        title: context.translate('online_mode'),
                        subtitle: context.translate('online_subtitle'),
                        color: Colors.green,
                        onTap: () {
                          Navigator.pushNamed(context, '/online_lobby');
                        },
                      )
                          .animate()
                          .fadeIn(delay: 900.ms)
                          .slideX(begin: 0.4)
                          .scale(begin: const Offset(0.95, 0.95)),
                      const SizedBox(height: 40),
                    ],
                  ),
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
            Expanded(
              child: Column(
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
            ),
          ],
        ),
      ),
    );
  }
}
