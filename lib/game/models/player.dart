import 'package:flutter/material.dart';

class Player {
  final String id;
  final String name;

  /// 🎟️ ficha visual elegida por el jugador (PNG)
  final String tokenAsset;

  /// 📍 posición en el tablero
  int position;

  /// ⏭️ turnos perdidos
  int skippedTurns;

  /// 🎲 conteo de 6 consecutivos
  int consecutiveSixes;

  /// =================================================
  /// 🆕 estados extra (NO rompen nada)
  /// =================================================

  /// 🏁 llegó a meta
  bool isFinished;

  /// 🎬 usado por animaciones (evita doble movimiento)
  bool isMoving;

  /// 👣 estadísticas / animaciones
  int stepsMoved;

  Player({
    required this.id,
    required this.name,
    required this.tokenAsset,
    this.position = 0,
    this.skippedTurns = 0,
    this.consecutiveSixes = 0,

    /// defaults seguros
    this.isFinished = false,
    this.isMoving = false,
    this.stepsMoved = 0,
  });

  /// =================================================
  /// 🔄 reset
  /// =================================================
  void resetToStart() {
    position = 0;
    skippedTurns = 0;
    consecutiveSixes = 0;
    isFinished = false;
    isMoving = false;
    stepsMoved = 0;
  }

  /// =================================================
  /// 🆕 helpers limpios (mejoran el engine)
  /// =================================================

  void moveBy(int steps) {
    position += steps;
    stepsMoved += steps;
  }

  void addSkip(int turns) {
    skippedTurns += turns;
  }

  void finish() {
    isFinished = true;
  }

  /// =================================================
  /// lógica existente (intocable)
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
      isFinished: isFinished,
      isMoving: isMoving,
      stepsMoved: stepsMoved,
    );
  }
}
