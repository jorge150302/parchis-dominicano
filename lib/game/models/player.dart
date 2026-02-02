import 'package:flutter/material.dart';

class Player {
  final String id;
  final String name;

  /// 📍 posición en el tablero
  int position;

  /// ⏭️ turnos perdidos
  int skippedTurns;

  /// 🎲 conteo de 6 consecutivos
  int consecutiveSixes;

  /// 🎟️ ficha visual elegida por el jugador (PNG)
  final String tokenAsset;

  Player({
    required this.id,
    required this.name,
    required this.tokenAsset,
    this.position = 0, // 👈 ahora empieza en INICIO (0)
    this.skippedTurns = 0,
    this.consecutiveSixes = 0,
  });

  /// =================================================
  /// 🔄 reset
  /// =================================================
  void resetToStart() {
    position = 0; // inicio real
    skippedTurns = 0;
    consecutiveSixes = 0;
  }

  /// =================================================
  /// lógica existente
  /// =================================================
  bool get mustSkipTurn => skippedTurns > 0;

  void consumeSkip() {
    if (skippedTurns > 0) skippedTurns--;
  }

  /// =================================================
  /// copia segura
  /// =================================================
  Player copy() {
    return Player(
      id: id,
      name: name,
      tokenAsset: tokenAsset,
      position: position,
      skippedTurns: skippedTurns,
      consecutiveSixes: consecutiveSixes,
    );
  }
}
