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
  
  /// Calcula cuánto XP se gana por una partida (valor base completo).
  /// El ratio offline (20%) y el tope diario son responsabilidad de SyncQueueService.
  static int calculateMatchXP({
    required int position, // 0 para 1º, 1 para 2º...
    required int totalPlayers,
    bool isOnline = true, // kept for call-site compat; ignored here
  }) {
    int xp = 0;

    if (totalPlayers == 4) {
      if (position == 0) xp = 100;
      else if (position == 1) xp = 40;
    } else if (totalPlayers == 3) {
      if (position == 0) xp = 80;
      else if (position == 1) xp = 20;
    } else if (totalPlayers == 2) {
      if (position == 0) xp = 60;
    }

    return xp;
  }
}
