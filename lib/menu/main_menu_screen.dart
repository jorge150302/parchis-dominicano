import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';
import '../config/language_provider.dart';
import '../service/socket_service.dart';
import '../service/prefs_service.dart';
import '../service/audio_service.dart';
import '../service/auth_service.dart';
import '../service/sync_queue_service.dart';
import '../game/logic/level_manager.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/avatar_selector_sheet.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  StreamSubscription? _socketSub;
  late final AuthService _authService;
  bool _rejoinDispatched = false;
  bool _isMigrationDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _authService.addListener(_onAuthChanged);

    _socketSub = context.read<SocketService>().events.listen((event) {
      if (event['event'] == 'user_data_deleted') {
        _handleAccountDeleted();
      } else if (event['event'] == 'error' &&
          (event['data']?['code']) == 'SESSION_CONFLICT') {
        _handleSessionConflict();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Profile may already be loaded if authStateChanges fired before listener was added.
      _tryRejoin();
      if (PrefsService.playerName.isEmpty) {
        _showWelcomeFlow();
      } else if (PrefsService.isFirstTime) {
        _showTutorialInvitation();
      }
    });
  }

  /// Attempts rejoin if profile has activeMatchId and we haven't dispatched yet.
  void _tryRejoin() {
    if (_rejoinDispatched || !mounted) return;
    if (_authService.needsMigrationDialog) return;
    final activeMatchId = _authService.profile?.activeMatchId;
    if (activeMatchId != null && activeMatchId.isNotEmpty) {
      _rejoinDispatched = true;
      _rejoinActiveMatch(activeMatchId);
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    
    // Solo mostramos el diálogo de migración si estamos en el menú principal y es la pantalla activa.
    // Esto evita que el diálogo aparezca encima de una partida en curso.
    final bool isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    
    if (_authService.needsMigrationDialog && isCurrent && !_isMigrationDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _authService.needsMigrationDialog && !_isMigrationDialogShowing) {
          _showMigrationDialog();
        }
      });
      return;
    }
    _tryRejoin();
  }

  Future<void> _rejoinActiveMatch(String roomCode) async {
    if (!mounted) return;
    try {
      await socketService.connect(Env.serverUrl);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushNamed(context, '/game', arguments: {
      'roomCode': roomCode,
      'playerCount': 4,
      'isRejoin': true,
    });
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _socketSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSessionConflict() async {
    socketService.disconnect();
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        title: Text(
          ctx.translate('session_conflict_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          ctx.translate('session_conflict_content'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () { AudioService.playClick(); Navigator.pop(ctx); },
            child: Text(ctx.translate('close'), style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _handleAccountDeleted() async {
    await PrefsService.clear();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<LanguageProvider>().translate('delete_account_success'),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showWelcomeFlow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WelcomeDialog(
        onSessionCheck: _checkSessionConflict,
        onComplete: (name) {
          if (!mounted) return;
          setState(() {
            PrefsService.playerName = name;
          });
        },
        onStartTutorial: () {
          if (!mounted) return;
          _startTutorial();
        },
      ),
    );
  }

  void _showTutorialInvitation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AlertDialogWrapper(
        canPop: false, // Bloquea el botón atrás en el tutorial inicial
        title: context.translate('tutorial_title'),
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
      barrierDismissible: true, // Permitir cerrar si se está editando desde el menú
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
              AudioService.playClick();
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

  void _showStatsDialog() {
    AudioService.playClick();
    final auth = context.read<AuthService>();
    final profile = auth.profile;

    // Prefer cloud values when signed in; fall back to local prefs
    final int matches = profile?.matchesPlayed ?? PrefsService.matchesPlayed;
    final int wins = profile?.wins ?? PrefsService.wins;
    final double winRate = matches > 0 ? wins / matches : 0.0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
          side: const BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        title: Text(
          ctx.translate('stats_title'),
          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatRow(
              icon: Icons.sports_esports,
              label: ctx.translate('stats_matches_played'),
              value: '$matches',
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 12),
            _StatRow(
              icon: Icons.emoji_events,
              label: ctx.translate('stats_wins'),
              value: '$wins',
              color: Colors.amber,
            ),
            const SizedBox(height: 12),
            _StatRow(
              icon: Icons.percent,
              label: ctx.translate('stats_win_rate'),
              value: '${(winRate * 100).toStringAsFixed(1)}%',
              color: Colors.greenAccent,
            ),
            if (matches == 0) ...[
              const SizedBox(height: 20),
              Text(
                ctx.translate('stats_no_data'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(ctx);
            },
            child: Text(
              ctx.translate('close').toUpperCase(),
              style: const TextStyle(color: Colors.orangeAccent),
            ),
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
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3),
            ),
            const SizedBox(height: 10),
            const Text("🇩🇴", style: TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(
              isSpanish ? "Hecho en República Dominicana" : "Made in Dominican Republic",
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const Divider(color: Colors.white24, height: 32),
            Text(
              isSpanish ? "CREADO POR" : "CREATED BY",
              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            const Text(
              "Jorge Luis Almánzar Valenzuela",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const Divider(color: Colors.white24, height: 32),
            const Text(
              "Flutter · Firebase · Dart Frog",
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
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

  void _showDeleteGameConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        title: Text(
          context.translate('delete_game'),
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.translate('delete_game_confirm'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(context);
            },
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              AudioService.playClick();
              PrefsService.savedLocalGame = null;
              Navigator.pop(context); // Cerrar confirmación
              Navigator.pop(context); // Cerrar diálogo de juego pendiente
            },
            child: Text(context.translate('delete_game'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMigrationDialog() {
    if (_isMigrationDialogShowing) return;
    _isMigrationDialogShowing = true;
    final auth = context.read<AuthService>();
    final syncQueue = context.read<SyncQueueService>();
    final guestXp = auth.guestXpBeforeMigration;
    final cloudXp = auth.profile?.xp ?? 0;
    final offlineDelta = guestXp - cloudXp; // XP earned offline, not total
    final guestLevel = LevelManager.calculateLevel(guestXp).toString();
    final cloudLevel = (auth.profile?.level ?? 1).toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.greenAccent, width: 2),
        ),
        title: Text(
          ctx.translate('migration_title'),
          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          ctx.translate('migration_content', args: {'guestLevel': guestLevel, 'cloudLevel': cloudLevel}),
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(ctx);
              auth.clearMigrationDialog();
              setState(() => _isMigrationDialogShowing = false);
            },
            child: Text(ctx.translate('migration_fresh', args: {'cloudLevel': cloudLevel}), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(ctx);
              syncQueue.enqueueGuestMigration(offlineDelta);
              auth.clearMigrationDialog();
              setState(() => _isMigrationDialogShowing = false);
            },
            child: Text(
              ctx.translate('migration_keep', args: {'guestLevel': guestLevel}),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _isMigrationDialogShowing = false);
    });
  }

  void _showDailyMasteryDialog({required VoidCallback onPlayAnyway}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amberAccent, width: 2),
        ),
        title: Text(
          context.translate('daily_mastery_title'),
          style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          context.translate('daily_mastery_content'),
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(context);
              onPlayAnyway();
            },
            child: Text(context.translate('daily_mastery_play_fun'), style: const TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(context);
              Navigator.pushNamed(context, '/online_lobby');
            },
            child: Text(context.translate('daily_mastery_go_online'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSignInRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        title: Text(
          context.translate('sign_in_required'),
          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.translate('sign_in_required_content'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(ctx);
            },
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Text('G', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4285F4))),
            label: Text(context.translate('sign_in_google'), style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              AudioService.playClick();
              Navigator.pop(ctx);
              final auth = context.read<AuthService>();
              final status = await auth.signInWithGoogle();
              if (!mounted) return;
              if (status == SignInStatus.success) {
                await _checkSessionConflict();
                if (!mounted) return;
                if (!auth.isSignedIn) return;
                Navigator.pushNamed(this.context, '/online_lobby');
              } else if (status == SignInStatus.offline || status == SignInStatus.error) {
                final key = status == SignInStatus.offline
                    ? 'auth_no_internet_signin'
                    : 'auth_signin_failed';
                showDialog(
                  context: this.context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: Colors.brown.shade900,
                    content: Text(ctx.translate(key), style: const TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(
                        onPressed: () { AudioService.playClick(); Navigator.pop(ctx); },
                        child: Text(ctx.translate('cancel'), style: const TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleOfflineClick() {
    AudioService.playClick();

    final syncQueue = context.read<SyncQueueService>();
    final allCapped = syncQueue.isDailyCapped(GameDifficulty.easy) &&
        syncQueue.isDailyCapped(GameDifficulty.medium) &&
        syncQueue.isDailyCapped(GameDifficulty.hard);
    if (allCapped) {
      // Every mode capped — warn upfront so user doesn't play a full game for 0 XP
      _showDailyMasteryDialog(onPlayAnyway: _navigateToOffline);
    } else {
      _navigateToOffline();
    }
  }

  void _navigateToOffline() {
    if (PrefsService.hasSavedGame) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.translate('pending_game_message'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    AudioService.playClick();
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    AudioService.playClick();
                    _showDeleteGameConfirm();
                  },
                  child: Text(
                    context.translate('delete_game'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    AudioService.playClick();
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
                  AudioService.playClick();
                  Navigator.pop(context);
                },
                child: Text(
                  context.translate('back'),
                  style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      Navigator.pushNamed(context, '/players');
    }
  }

  void _showSettings(BuildContext context) {
    AudioService.playClick();
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
                          AudioService.playClick();
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
                          AudioService.playClick();
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
                      activeThumbColor: Colors.orange,
                      onChanged: (bool value) {
                        AudioService.playClick();
                        setDialogState(() => PrefsService.soundEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration, color: Colors.white70),
                      title: Text(context.translate('vibration'), style: const TextStyle(color: Colors.white70)),
                      value: PrefsService.vibrationEnabled,
                      activeThumbColor: Colors.orange,
                      onChanged: (bool value) {
                        AudioService.playClick();
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
                        AudioService.playClick();
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/privacy');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white70),
                      title: Text(context.translate('credits'), style: const TextStyle(color: Colors.white70)),
                      onTap: () {
                        AudioService.playClick();
                        Navigator.pop(context);
                        _showCreditsDialog();
                      },
                    ),
                    // ── Google Account ──────────────────────────────────
                    const Divider(color: Colors.white24),
                    Consumer<AuthService>(
                      builder: (context, auth, _) {
                        if (auth.isSignedIn) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: UserAvatarWidget(
                                  profile: auth.profile,
                                  firebaseUser: auth.firebaseUser,
                                  radius: 18,
                                ),
                                title: Text(
                                  auth.profile?.displayName.isNotEmpty == true
                                      ? auth.profile!.displayName
                                      : PrefsService.playerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  auth.firebaseUser?.email ?? '',
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white30),
                                    foregroundColor: Colors.white70,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.logout, size: 18),
                                  label: Text(
                                    context.translate('sign_out_google'),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () {
                                    AudioService.playClick();
                                    showDialog(
                                      context: this.context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: Colors.brown.shade900,
                                        title: Text(ctx.translate('auth_signout_confirm_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        content: Text(ctx.translate('auth_signout_confirm_body'), style: const TextStyle(color: Colors.white70)),
                                        actions: [
                                          TextButton(
                                            onPressed: () { AudioService.playClick(); Navigator.pop(ctx); },
                                            child: Text(ctx.translate('cancel'), style: const TextStyle(color: Colors.white70)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () async {
                                              AudioService.playClick();
                                              Navigator.pop(ctx);
                                              final status = await auth.signOut();
                                              if (!mounted) return;
                                              switch (status) {
                                                case SignOutStatus.success:
                                                  Navigator.pop(this.context);
                                                case SignOutStatus.offline:
                                                  showDialog(
                                                    context: this.context,
                                                    builder: (d) => AlertDialog(
                                                      backgroundColor: Colors.brown.shade900,
                                                      content: Text(d.translate('auth_no_internet_signout'), style: const TextStyle(color: Colors.white)),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () { AudioService.playClick(); Navigator.pop(d); },
                                                          child: Text(d.translate('cancel'), style: const TextStyle(color: Colors.white70)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                              }
                                            },
                                            child: Text(ctx.translate('auth_signout_confirm_btn'), style: const TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Divider(color: Colors.white24),
                              ListTile(
                                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                title: Text(context.translate('delete_account'), style: const TextStyle(color: Colors.redAccent)),
                                onTap: () {
                                  AudioService.playClick();
                                  _confirmDeleteAccount(context);
                                },
                              ),
                            ],
                          );
                        }

                        // Not signed in — show Google Sign-In button
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                              ),
                              icon: const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                              label: Text(
                                context.translate('sign_in_google'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              onPressed: () async {
                                AudioService.playClick();
                                final status = await auth.signInWithGoogle();
                                if (!mounted) return;
                                if (status == SignInStatus.success) {
                                  await _checkSessionConflict();
                                  if (!mounted) return;
                                }
                                if (status == SignInStatus.offline || status == SignInStatus.error) {
                                  final key = status == SignInStatus.offline
                                      ? 'auth_no_internet_signin'
                                      : 'auth_signin_failed';
                                  showDialog(
                                    context: this.context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: Colors.brown.shade900,
                                      content: Text(ctx.translate(key), style: const TextStyle(color: Colors.white)),
                                      actions: [
                                        TextButton(
                                          onPressed: () { AudioService.playClick(); Navigator.pop(ctx); },
                                          child: Text(ctx.translate('cancel'), style: const TextStyle(color: Colors.white70)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                // success: Consumer rebuilds dialog automatically
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'v1.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    AudioService.playClick();
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
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        title: Text(context.translate('delete_account'), style: const TextStyle(color: Colors.red)),
        content: Text(
          context.translate('delete_account_confirm'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(ctx);
            },
            child: Text(context.translate('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              AudioService.playClick();
              Navigator.pop(ctx);
              await _runDeleteAccount();
            },
            child: Text(context.translate('confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _runDeleteAccount() async {
    if (!mounted) return;

    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.brown,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(width: 16),
            Text(ctx.translate('auth_delete_loading'), style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    final auth = this.context.read<AuthService>();
    final socket = this.context.read<SocketService>();
    final playerId = PrefsService.playerId;

    final status = await auth.deleteAccount();

    if (!mounted) return;
    Navigator.of(this.context).pop();

    switch (status) {
      case DeleteAccountStatus.success:
        socket.send('delete_user_data', {'playerId': playerId});
        _handleAccountDeleted();
      case DeleteAccountStatus.cancelled:
        break;
      case DeleteAccountStatus.offline:
        _showDeleteError('auth_no_internet_delete');
      case DeleteAccountStatus.error:
        _showDeleteError('auth_delete_failed');
    }
  }

  void _showDeleteError(String messageKey) {
    showDialog(
      context: this.context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.brown.shade900,
        title: Text(ctx.translate('auth_delete_title'), style: const TextStyle(color: Colors.red)),
        content: Text(ctx.translate(messageKey), style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () { AudioService.playClick(); Navigator.pop(ctx); },
            child: Text(ctx.translate('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(ctx);
              _runDeleteAccount();
            },
            child: Text(ctx.translate('confirm'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getLevelTooltipMessage(int playerLevel) {
    if (playerLevel >= 100) return context.translate('level_max');

    final int currentXpInLevel = LevelManager.getXpInCurrentLevel(PrefsService.totalXp);
    final int xpRequired = LevelManager.xpRequiredForLevel(playerLevel);
    final nextRank = LevelManager.getNextRankInfo(playerLevel);

    String message = context.translate('level_xp_progress', args: {
      'current': '$currentXpInLevel',
      'required': '$xpRequired',
      'next': '${playerLevel + 1}',
    });

    if (nextRank != null) {
      final int totalXpNeededForNextRank = LevelManager.totalXpToReachLevel(nextRank['level']);
      final int xpMissingForNextRank = totalXpNeededForNextRank - PrefsService.totalXp;
      message += context.translate('level_rank_missing', args: {
        'missing': '$xpMissingForNextRank',
        'rank': '${nextRank['name']}',
      });
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    // Watch AuthService so the header re-reads PrefsService values after sign-in / XP updates.
    final auth = context.watch<AuthService>();
    final int playerLevel = PrefsService.playerLevel;
    final String rankName = LevelManager.getRankName(playerLevel);

    // Si volvemos al menú y hay un diálogo de migración pendiente, lo mostramos.
    if (auth.needsMigrationDialog && !_isMigrationDialogShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && auth.needsMigrationDialog && !_isMigrationDialogShowing) {
          final bool isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
          if (isCurrent) _showMigrationDialog();
        }
      });
    }

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
              top: 36,
              left: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlayerProfileHeader(
                    playerLevel: playerLevel,
                    rankName: rankName,
                    tooltipMessage: _getLevelTooltipMessage(playerLevel),
                    onTapName: _showNameDialog,
                    onSignIn: _checkSessionConflict,
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.bar_chart, color: Colors.white70, size: 22),
                    onPressed: _showStatsDialog,
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
                          AudioService.playClick();
                          final auth = context.read<AuthService>();
                          if (!auth.isSignedIn) {
                            _showSignInRequiredDialog();
                            return;
                          }
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

// ─── Player Profile Header ────────────────────────────────────────────────────

// Session-conflict helpers — defined at file level so _WelcomeDialogState
// can call them via callback without needing access to _MainMenuScreenState.

Future<void> _checkSessionConflict() async {
  try {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    socketService.cacheIdToken(token);
    await socketService.connect(Env.serverUrl);
    socketService.send('register_session', {});
    await Future.delayed(const Duration(seconds: 2));
  } catch (_) {}
}

class _PlayerProfileHeader extends StatelessWidget {
  final int playerLevel;
  final String rankName;
  final String tooltipMessage;
  final VoidCallback onTapName;
  final Future<void> Function()? onSignIn;

  const _PlayerProfileHeader({
    required this.playerLevel,
    required this.rankName,
    required this.tooltipMessage,
    required this.onTapName,
    this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, SyncQueueService>(
      builder: (context, auth, syncQueue, _) {
        final profile = auth.profile;
        final name = profile?.displayName.isNotEmpty == true
            ? profile!.displayName
            : PrefsService.playerName;

        return Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar — tap to change ──────────────────────────────────
              GestureDetector(
                onTap: auth.isSignedIn ? () => showAvatarSelectorSheet(context, auth) : null,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatarWidget(
                        profile: profile,
                        firebaseUser: auth.firebaseUser,
                        radius: 22,
                      ),
                      if (auth.isSignedIn)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black54, width: 1.5),
                            ),
                            child: const Icon(Icons.edit, size: 11, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ── Name + XP + chips ───────────────────────────────────────
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name row — tap to rename
                    GestureDetector(
                      onTap: onTapName,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name.isNotEmpty ? name : '...',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (auth.isSignedIn)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified, color: Colors.blueAccent, size: 12),
                            ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.edit, color: Colors.white54, size: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    // XP bar
                    Tooltip(
                      message: tooltipMessage,
                      triggerMode: TooltipTriggerMode.tap,
                      preferBelow: true,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade800,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orangeAccent),
                      ),
                      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      child: SizedBox(
                        height: 20,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: LevelManager.getLevelProgress(PrefsService.totalXp),
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orangeAccent.withValues(alpha: 0.55),
                                ),
                                minHeight: 20,
                              ),
                            ),
                            Center(
                              child: Text(
                                '$rankName  Lv.$playerLevel',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Sync badge or Google Sign-In chip
                    if (syncQueue.isSyncing)
                      _statusChip(Icons.sync, context.translate('syncing'), Colors.blueAccent)
                    else if (syncQueue.hasPendingReceipts)
                      _statusChip(Icons.upload, context.translate('offline_xp_pending'), Colors.amberAccent)
                    else if (!auth.isSignedIn)
                      _googleSignInChip(context, auth),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _googleSignInChip(BuildContext context, AuthService auth) {
    return GestureDetector(
      onTap: () async {
        AudioService.playClick();
        final status = await auth.signInWithGoogle();
        if (!context.mounted) return;
        if (status == SignInStatus.success) {
          await onSignIn?.call();
          if (!context.mounted) return;
        }
        if (status == SignInStatus.offline || status == SignInStatus.error) {
          final key = status == SignInStatus.offline
              ? 'auth_no_internet_signin'
              : 'auth_signin_failed';
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.brown.shade900,
              content: Text(ctx.translate(key), style: const TextStyle(color: Colors.white)),
              actions: [
                TextButton(
                  onPressed: () { AudioService.playClick(); Navigator.pop(ctx); },
                  child: Text(ctx.translate('cancel'), style: const TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.login, color: Colors.white70, size: 10),
            const SizedBox(width: 4),
            Text(
              context.translate('sign_in_google'),
              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AlertDialogWrapper extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool canPop; // Propiedad para controlar el cierre

  const _AlertDialogWrapper({
    required this.title,
    required this.content,
    required this.actions,
    this.canPop = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      child: AlertDialog(
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
  final VoidCallback onStartTutorial;
  final Future<void> Function()? onSessionCheck;
  const _WelcomeDialog({required this.onComplete, required this.onStartTutorial, this.onSessionCheck});

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  int _step = 0;
  bool _isLoading = false;
  bool _signedInWithGoogle = false;
  final _nameController = TextEditingController();
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    AudioService.playClick();
    setState(() => _isLoading = true);
    final auth = context.read<AuthService>();
    final status = await auth.signInWithGoogle();
    if (!mounted) return;

    if (status == SignInStatus.cancelled) {
      setState(() => _isLoading = false);
      return;
    }

    if (status == SignInStatus.offline || status == SignInStatus.error) {
      setState(() => _isLoading = false);
      final key = status == SignInStatus.offline
          ? 'auth_no_internet_signin'
          : 'auth_signin_failed';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.brown.shade900,
          content: Text(ctx.translate(key), style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () { AudioService.playClick(); Navigator.pop(ctx); },
              child: Text(ctx.translate('cancel'), style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
      return;
    }

    // Session conflict check: ensure this account isn't active on another device.
    await widget.onSessionCheck?.call();
    if (!mounted) return;
    if (!auth.isSignedIn) {
      setState(() => _isLoading = false);
      return;
    }

    // cancelled or success — advance to name step
    final firebaseUser = auth.firebaseUser;
    final fullName = firebaseUser?.displayName ?? auth.profile?.displayName ?? '';
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final firstName = parts.isNotEmpty ? parts.first : fullName.trim();
    setState(() {
      _isLoading = false;
      _signedInWithGoogle = auth.isSignedIn;
      if (firstName.isNotEmpty) _nameController.text = firstName;
      _step = 1;
    });
  }

  void _handleGuest() {
    AudioService.playClick();
    setState(() {
      _nameController.clear();
      _signedInWithGoogle = false;
      _step = 1;
    });
  }

  void _handleConfirm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AudioService.playClick();
      setState(() => _nameError = context.translate('enter_name_error', listen: false));
      return;
    }
    setState(() => _nameError = null);
    AudioService.playClick();
    widget.onComplete(name);
    setState(() => _step = 2);
  }

  void _handleTutorialSkip() {
    AudioService.playClick();
    PrefsService.isFirstTime = false;
    Navigator.pop(context);
  }

  void _handleTutorialStart() {
    AudioService.playClick();
    PrefsService.isFirstTime = false;
    Navigator.pop(context);
    widget.onStartTutorial();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.brown.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 2),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Column(
          children: [
            Text(
              context.translate('welcome_to_parche'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _StepIndicator(step: _step),
            const SizedBox(height: 8),
            Text(
              _step == 0
                  ? context.translate('create_your_profile')
                  : _step == 1 
                      ? context.translate('confirm_your_name')
                      : context.translate('tutorial_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          ),
          child: _step == 0 
              ? _buildStep0(context) 
              : _step == 1 
                  ? _buildStep1(context)
                  : _buildStep2(context),
        ),
        ),
        actions: _step == 1
            ? [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: _handleConfirm,
                  child: Text(
                    context.translate('confirm'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ]
            : _step == 2
                ? [
                    TextButton(
                      onPressed: _handleTutorialSkip,
                      child: Text(context.translate('tutorial_skip'), style: const TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: _handleTutorialStart,
                      child: Text(context.translate('tutorial_start'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ]
                : null,
      ),
    );
  }

  Widget _buildStep0(BuildContext context) {
    return SizedBox(
      key: const ValueKey('step0'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 2,
            ),
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                  )
                : const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4285F4),
                    ),
                  ),
            label: Text(
              context.translate('continue_with_google'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white38),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _handleGuest,
            child: Text(context.translate('play_as_guest')),
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              children: [
                TextSpan(text: context.translate('privacy_policy_agree_prefix')),
                TextSpan(
                  text: context.translate('privacy_policy'),
                  style: const TextStyle(
                    color: Colors.orange,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => launchUrl(Uri.parse('https://parche.app/privacy')),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStep1(BuildContext context) {
    final auth = context.watch<AuthService>();
    final double avatarRadius = _signedInWithGoogle ? 28 : 36;
    final double topGap = _signedInWithGoogle ? 8 : 16;
    return SizedBox(
      key: const ValueKey('step1'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatarWidget(
              profile: auth.profile,
              firebaseUser: auth.firebaseUser,
              radius: avatarRadius,
            ),
            SizedBox(height: topGap),
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _handleConfirm(),
              onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
              decoration: InputDecoration(
                hintText: context.translate('name_hint'),
                hintStyle: const TextStyle(color: Colors.white54),
                errorText: _nameError,
                errorStyle: const TextStyle(color: Colors.redAccent),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.orange),
                ),
                errorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent),
                ),
                focusedErrorBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(BuildContext context) {
    return SizedBox(
      key: const ValueKey('step2'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 64, color: Colors.orangeAccent),
          const SizedBox(height: 16),
          Text(
            context.translate('tutorial_content'),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepDot(filled: step >= 0),
        Container(width: 24, height: 2, color: step >= 1 ? Colors.orange : Colors.white24),
        _StepDot(filled: step >= 1),
        Container(width: 24, height: 2, color: step >= 2 ? Colors.orange : Colors.white24),
        _StepDot(filled: step >= 2),
        const SizedBox(width: 12),
        Text(
          context.translate('step_n_of_3', args: {'n': '${step + 1}'}),
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool filled;
  const _StepDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Colors.orange : Colors.white24,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
