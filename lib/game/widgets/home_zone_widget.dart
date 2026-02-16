import 'package:flutter/material.dart';

import '../models/player.dart';

class HomeZoneWidget extends StatelessWidget {
  final Player player;

  const HomeZoneWidget({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    // ✅ PADDING Y TAMAÑO REDUCIDOS
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Inicio',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: player.position == 0
                ? [Image.asset(player.tokenAsset, width: 20, height: 20)]
                : [],
          ),
        ],
      ),
    );
  }
}
