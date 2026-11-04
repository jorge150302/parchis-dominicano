enum GameDifficulty { easy, medium, hard }

class LevelManager {
  /// Retorna la cantidad de XP necesaria para subir AL SIGUIENTE nivel desde el nivel actual.
  static int xpRequiredForLevel(int level) {
    if (level >= 91) return 1000; // Leyenda
    if (level >= 66) return 600;  // Maestro
    if (level >= 41) return 400;  // Experto
    if (level >= 21) return 250;  // Estratega
    if (level >= 9) return 150;   // Aprendiz
    return 100;                  // Novato
  }

  /// Retorna el nombre del rango según el nivel.
  static String getRankName(int level) {
    if (level >= 91) return 'Leyenda';
    if (level >= 66) return 'Maestro';
    if (level >= 41) return 'Experto';
    if (level >= 21) return 'Estratega';
    if (level >= 9) return 'Aprendiz';
    return 'Novato';
  }

  /// Calcula el nivel actual basándose en el XP total acumulado.
  static int calculateLevel(int totalXp) {
    int level = 1;
    int remainingXp = totalXp;
    while (level < 100 && remainingXp >= xpRequiredForLevel(level)) {
      remainingXp -= xpRequiredForLevel(level);
      level++;
    }
    return level;
  }

  /// Retorna cuánta XP tiene el jugador dentro de su nivel actual.
  static int getXpInCurrentLevel(int totalXp) {
    int level = 1;
    int remainingXp = totalXp;
    while (level < 100 && remainingXp >= xpRequiredForLevel(level)) {
      remainingXp -= xpRequiredForLevel(level);
      level++;
    }
    return remainingXp;
  }

  /// Calcula el progreso (0.0 a 1.0) dentro del nivel actual.
  static double getLevelProgress(int totalXp) {
    int level = calculateLevel(totalXp);
    if (level >= 100) return 1.0;
    int remainingXp = getXpInCurrentLevel(totalXp);
    return remainingXp / xpRequiredForLevel(level);
  }

  /// Retorna información sobre el próximo gran rango.
  static Map<String, dynamic>? getNextRankInfo(int currentLevel) {
    if (currentLevel < 9) return {'name': 'Aprendiz', 'level': 9};
    if (currentLevel < 21) return {'name': 'Estratega', 'level': 21};
    if (currentLevel < 41) return {'name': 'Experto', 'level': 41};
    if (currentLevel < 66) return {'name': 'Maestro', 'level': 66};
    if (currentLevel < 91) return {'name': 'Leyenda', 'level': 91};
    return null;
  }

  /// Calcula el XP total necesario para alcanzar un nivel específico.
  static int totalXpToReachLevel(int targetLevel) {
    int total = 0;
    for (int i = 1; i < targetLevel; i++) {
      total += xpRequiredForLevel(i);
    }
    return total;
  }
  
  /// Calcula cuánto XP se gana por una partida.
  /// En partidas de 4 jugadores, el 4º lugar recibe 0 XP.
  /// El ratio offline (20%) y el tope diario son responsabilidad de SyncQueueService.
  static int calculateMatchXP({
    required int position, // 0 para 1º, 1 para 2º...
    required int totalPlayers,
    GameDifficulty difficulty = GameDifficulty.medium,
  }) {
    int baseXp = 0;

    if (totalPlayers == 4) {
      if (position == 0) { baseXp = 100; }
      else if (position == 1) { baseXp = 40; }
      else if (position == 2) { baseXp = 15; }
      // 4th place: 0
    } else if (totalPlayers == 3) {
      if (position == 0) { baseXp = 80; }
      else if (position == 1) { baseXp = 20; }
      else if (position == 2) { baseXp = 10; }
    } else if (totalPlayers == 2) {
      if (position == 0) { baseXp = 60; }
      else if (position == 1) { baseXp = 10; }
    }

    const multipliers = {
      GameDifficulty.easy: 0.5,
      GameDifficulty.medium: 1.0,
      GameDifficulty.hard: 1.5,
    };

    return (baseXp * multipliers[difficulty]!).floor();
  }
}
