import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_parchis/game/logic/level_manager.dart';

void main() {
  group('LevelManager Tests', () {
    test('xpRequiredForLevel returns correct values', () {
      expect(LevelManager.xpRequiredForLevel(1), 100);
      expect(LevelManager.xpRequiredForLevel(10), 150);
      expect(LevelManager.xpRequiredForLevel(25), 250);
      expect(LevelManager.xpRequiredForLevel(50), 400);
      expect(LevelManager.xpRequiredForLevel(70), 600);
      expect(LevelManager.xpRequiredForLevel(95), 1000);
    });

    test('getRankName returns correct names', () {
      expect(LevelManager.getRankName(5), 'Novato');
      expect(LevelManager.getRankName(15), 'Aprendiz');
      expect(LevelManager.getRankName(30), 'Estratega');
      expect(LevelManager.getRankName(50), 'Experto');
      expect(LevelManager.getRankName(80), 'Maestro');
      expect(LevelManager.getRankName(95), 'Leyenda');
    });

    test('calculateLevel works correctly', () {
      expect(LevelManager.calculateLevel(0), 1);
      expect(LevelManager.calculateLevel(50), 1);
      expect(LevelManager.calculateLevel(100), 2);
      expect(LevelManager.calculateLevel(200), 3);
      // Level 1 (100) + Level 2 (100) + ... Level 8 (100) = 800 XP to reach Level 9
      expect(LevelManager.calculateLevel(799), 8);
      expect(LevelManager.calculateLevel(800), 9);
    });

    test('calculateMatchXP works correctly for 2 players', () {
      expect(LevelManager.calculateMatchXP(position: 0, totalPlayers: 2, difficulty: GameDifficulty.medium), 60);
      expect(LevelManager.calculateMatchXP(position: 1, totalPlayers: 2, difficulty: GameDifficulty.medium), 10);
      
      // Easy difficulty (0.5x)
      expect(LevelManager.calculateMatchXP(position: 0, totalPlayers: 2, difficulty: GameDifficulty.easy), 30);
      
      // Hard difficulty (1.5x)
      expect(LevelManager.calculateMatchXP(position: 0, totalPlayers: 2, difficulty: GameDifficulty.hard), 90);
    });

    test('calculateMatchXP works correctly for 4 players', () {
      expect(LevelManager.calculateMatchXP(position: 0, totalPlayers: 4, difficulty: GameDifficulty.medium), 100);
      expect(LevelManager.calculateMatchXP(position: 1, totalPlayers: 4, difficulty: GameDifficulty.medium), 40);
      expect(LevelManager.calculateMatchXP(position: 2, totalPlayers: 4, difficulty: GameDifficulty.medium), 15);
      expect(LevelManager.calculateMatchXP(position: 3, totalPlayers: 4, difficulty: GameDifficulty.medium), 0);
    });
  });
}
