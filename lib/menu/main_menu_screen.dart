import 'dart:async';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/language_provider.dart';
import '../service/socket_service.dart';
import '../service/prefs_service.dart';
import '../service/audio_service.dart'; // Importamos el servicio de audio

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PrefsService.playerName.isEmpty) {
        _showWelcomeFlow();
      } else if (PrefsService.isFirstTime) {
        _showTutorialInvitation();
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

  void _showWelcomeFlow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WelcomeDialog(
        onComplete: (name) {
          if (!mounted) return;
          setState(() {
            PrefsService.playerName = name;
          });
          // Pequeño delay para asegurar que el diálogo anterior se cerró completamente
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) _showTutorialInvitation();
          });
        },
      ),
    );
  }

  void _showTutorialInvitation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        title: Text(
          context.translate('tutorial_title'),
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          context.translate('tutorial_content'),
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              PrefsService.isFirstTime = false;
              Navigator.pop(context);
            },
            child: Text(context.translate('tutorial_skip'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              AudioService.playClick();
              PrefsService.isFirstTime = false;
              Navigator.pop(context);
              _startTutorial();
            },
            child: Text(context.translate('tutorial_start'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startTutorial() {
    Navigator.pushNamed(context, '/game', arguments: {
      'playerCount': 2,
      'vsAI': true,
      'isTutorial': true,
    });
  }

  void _showNameDialog() {
    final TextEditingController nameController = TextEditingController(text: PrefsService.playerName);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AlertDialogWrapper(
        title: context.translate('enter_name_title'),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: context.translate('name_hint'),
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              AudioService.playClick(); // ✅ Sonido
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  PrefsService.playerName = nameController.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: Text(context.translate('confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreditsDialog() {
    final bool isSpanish = context.read<LanguageProvider>().currentLanguage == Language.es;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: const BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        title: Text(
          isSpanish ? "CRÉDITOS" : "CREDITS",
          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "PARCHÉ",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            const SizedBox(height: 10),
            const Text(
              "v1.0.0",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const Divider(color: Colors.white24, height: 30),
            Text(
              isSpanish ? "EFECTOS DE SONIDO" : "SOUND EFFECTS",
              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                children: [
                  const TextSpan(text: "Sound Effect by "),
                  TextSpan(
                    text: "u_qpfzpydtro",
                    style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      AudioService.playClick(); // ✅ Sonido
                      launchUrl(Uri.parse("https://pixabay.com/users/u_qpfzpydtro-29496424/"));
                    },
                  ),
                  const TextSpan(text: " from "),
                  TextSpan(
                    text: "Pixabay",
                    style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
                    recognizer: TapGestureRecognizer()..onTap = () {
                      AudioService.playClick(); // ✅ Sonido
                      launchUrl(Uri.parse("https://pixabay.com/"));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick(); // ✅ Sonido
              Navigator.pop(context);
            },
            child: Text(isSpanish ? "CERRAR" : "CLOSE", style: const TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

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

  void _handleOfflineClick() {
    AudioService.playClick(); // ✅ Sonido
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
            context.translate('pending_game_title'),
            style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            context.translate('pending_game_message'),
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
                      AudioService.playClick(); // ✅ Sonido
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
                      AudioService.playClick(); // ✅ Sonido
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/players');
                    },
                    child: Text(
                      context.translate('start_new_game'),
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Divider(color: Colors.white24),
                TextButton(
                  onPressed: () {
                    AudioService.playClick(); // ✅ Sonido
                    Navigator.pop(context);
                  },
                  child: Text(
                    context.translate('back'),
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
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
    AudioService.playClick(); // ✅ Sonido al abrir
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
              content: SingleChildScrollView(
                child: Column(
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
                          AudioService.playClick(); // ✅ Sonido
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
                    ListTile(
                      leading: const Icon(Icons.speed, color: Colors.white70),
                      title: Text(context.translate('game_speed'), style: const TextStyle(color: Colors.white70)),
                      trailing: DropdownButton<GameSpeed>(
                        dropdownColor: Colors.brown.shade800,
                        value: PrefsService.gameSpeed,
                        underline: const SizedBox(),
                        onChanged: (GameSpeed? newSpeed) {
                          AudioService.playClick(); // ✅ Sonido
                          if (newSpeed != null) {
                            setDialogState(() => PrefsService.gameSpeed = newSpeed);
                          }
                        },
                        items: [
                          DropdownMenuItem(value: GameSpeed.normal, child: Text(context.translate('speed_normal'), style: const TextStyle(color: Colors.white))),
                          DropdownMenuItem(value: GameSpeed.fast, child: Text(context.translate('speed_fast'), style: const TextStyle(color: Colors.white))),
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
                        AudioService.playClick(); // ✅ Sonido
                        setDialogState(() => PrefsService.soundEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration, color: Colors.white70),
                      title: Text(context.translate('vibration'), style: const TextStyle(color: Colors.white70)),
                      value: PrefsService.vibrationEnabled,
                      activeColor: Colors.orange,
                      onChanged: (bool value) {
                        AudioService.playClick(); // ✅ Sonido
                        setDialogState(() => PrefsService.vibrationEnabled = value);
                      },
                    ),
                    const Divider(color: Colors.white24),
                    ListTile(
                      leading: const Icon(Icons.help_outline, color: Colors.white70),
                      title: Text(context.translate('tutorial'), style: const TextStyle(color: Colors.white70)),
                      onTap: () {
                        AudioService.playClick();
                        Navigator.pop(context);
                        _startTutorial();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
                      title: Text(context.translate('privacy_policy'), style: const TextStyle(color: Colors.white70)),
                      onTap: () {
                        AudioService.playClick(); // ✅ Sonido
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/privacy');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      title: Text(context.translate('delete_account'), style: const TextStyle(color: Colors.redAccent)),
                      onTap: () {
                        AudioService.playClick(); // ✅ Sonido
                        _confirmDeleteAccount(context);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    AudioService.playClick(); // ✅ Sonido
                    Navigator.pop(context);
                  },
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
            onPressed: () {
              AudioService.playClick(); // ✅ Sonido
              Navigator.pop(context);
            },
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              AudioService.playClick(); // ✅ Sonido
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
    final String playerName = PrefsService.playerName;

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
            Positioned(
              top: 40,
              left: 20,
              child: Row(
                children: [
                  if (playerName.isNotEmpty)
                    GestureDetector(
                      onTap: _showNameDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, color: Colors.orangeAccent, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              playerName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, color: Colors.white54, size: 12),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white70, size: 24),
                    onPressed: _showCreditsDialog,
                  ).animate().fadeIn(delay: 700.ms).scale(),
                ],
              ),
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
                        onTap: _handleOfflineClick,
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
                          AudioService.playClick(); // ✅ Sonido
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

class _AlertDialogWrapper extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const _AlertDialogWrapper({
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.brown.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.orange, width: 2),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
      ),
      content: content,
      actions: actions,
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
          color: Colors.white.withValues(alpha: 0.88),
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

class _WelcomeDialog extends StatefulWidget {
  final Function(String) onComplete;
  const _WelcomeDialog({required this.onComplete});

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  int _step = 0; // 0: Idioma, 1: Nombre
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.brown.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.orange, width: 2),
      ),
      title: Text(
        _step == 0 ? "BIENVENIDO / WELCOME" : context.translate('enter_name_title'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
      ),
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 0 ? _buildLanguageStep() : _buildNameStep(),
      ),
      actions: [
        if (_step == 1)
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              AudioService.playClick(); // ✅ Sonido
              if (_nameController.text.trim().isNotEmpty) {
                final String name = _nameController.text.trim();
                Navigator.pop(context); // Primero cerramos este diálogo
                widget.onComplete(name); // Luego notificamos para abrir el siguiente
              }
            },
            child: Text(context.translate('confirm'), style: const TextStyle(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildLanguageStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Selecciona tu idioma\nSelect your language",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        _langOption("Español", "🇪🇸", Language.es),
        const SizedBox(height: 12),
        _langOption("English", "🇺🇸", Language.en),
      ],
    );
  }

  Widget _langOption(String label, String flag, Language lang) {
    return ListTile(
      tileColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      onTap: () {
        AudioService.playClick(); // ✅ Sonido
        context.read<LanguageProvider>().setLanguage(lang);
        setState(() => _step = 1);
      },
    );
  }

  Widget _buildNameStep() {
    return TextField(
      controller: _nameController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: context.translate('name_hint'),
        hintStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
      ),
    );
  }
}
