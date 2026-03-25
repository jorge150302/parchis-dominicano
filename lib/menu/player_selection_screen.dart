import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
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

  void _updateAINames() {
    if (selectedPlayers == null) return;
    final lang = context.read<LanguageProvider>();

    if (vsAI) {
      List<String> aiNameKeys = ['ai_name_1', 'ai_name_2', 'ai_name_3', 'ai_name_4', 'ai_name_5', 'ai_name_6'];
      aiNameKeys.shuffle();

      for (int i = 1; i < selectedPlayers!; i++) {
        _nameControllers[i].text = lang.translate(aiNameKeys[i % aiNameKeys.length]);
      }
    } else {
      for (int i = 1; i < 4; i++) {
        _nameControllers[i].clear();
      }
    }
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
                              onChanged: (v) {
                                setState(() {
                                  vsAI = v;
                                  _updateAINames();
                                });
                              },
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
                
                    Builder(
                      builder: (btnContext) {
                        return ElevatedButton(
                          onPressed: selectedPlayers == null 
                            ? null 
                            : () {
                              final lang = btnContext.read<LanguageProvider>();

                              int countToValidate = vsAI ? 1 : selectedPlayers!;
                              bool hasEmptyFields = false;

                              for (int i = 0; i < countToValidate; i++) {
                                if (_nameControllers[i].text.trim().isEmpty) {
                                  hasEmptyFields = true;
                                  break;
                                }
                              }

                              if (hasEmptyFields) {
                                ScaffoldMessenger.of(btnContext).clearSnackBars();
                                ScaffoldMessenger.of(btnContext).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      lang.translate('all_names_mandatory'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                    margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                );
                                return;
                              }

                              List<String> playerNames = [];
                              for (int i = 0; i < selectedPlayers!; i++) {
                                playerNames.add(_nameControllers[i].text.trim());
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
                            backgroundColor: selectedPlayers == null ? Colors.grey : Colors.orangeAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 10,
                          ),
                          child: Text(
                            context.translate('start_game'), 
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)
                          ),
                        );
                      }
                    ).animate(target: selectedPlayers == null ? 0 : 1).fadeIn(delay: 600.ms),
                
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
    int count = selectedPlayers!;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: List.generate(count, (i) {
          bool isAIField = vsAI && i > 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _nameControllers[i],
              enabled: !isAIField,
              style: TextStyle(color: isAIField ? Colors.orangeAccent : Colors.white),
              decoration: InputDecoration(
                labelText: context.translate('player_n_name', args: {'player': '${i + 1}'}),
                labelStyle: TextStyle(color: isAIField ? Colors.orangeAccent.withOpacity(0.7) : Colors.orangeAccent),
                disabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent, width: 0.5)),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent, width: 2)),
              ),
            ),
          );
        }),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _playerCard(int players) {
    final isSelected = selectedPlayers == players;

    Widget iconWidget() {
      if (players == 2) return Icon(Icons.group, size: 32, color: isSelected ? Colors.white : Colors.black87);
      if (players == 3) return Icon(Icons.groups, size: 32, color: isSelected ? Colors.white : Colors.black87);
      return Image.asset('assets/images/icon_4_players.png', width: 34, height: 34, color: isSelected ? Colors.white : null);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPlayers = players;
          _updateAINames();
        });
      },
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
