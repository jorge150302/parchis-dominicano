import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../config/language_provider.dart';

/// Shown in a public waiting room once the server offers it (after 45 s with
/// seats still empty): the player may start right away against AI, for half
/// the XP. Never happens on its own.
class AiFillOffer extends StatelessWidget {
  const AiFillOffer({super.key, required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          context.translate('ai_fill_offer'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onAccept,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade600,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  context.translate('ai_fill_button'),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.translate('ai_fill_xp_hint'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    ).animate().fadeIn();
  }
}
