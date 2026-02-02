import 'board.dart';
import 'player.dart';

class GameState {
  final Board board;
  final List<Player> players;
  final int currentTurn;
  final int diceValue;
  final bool gameOver;

  GameState({
    required this.board,
    required this.players,
    required this.currentTurn,
    required this.diceValue,
    required this.gameOver,
  });

  GameState copyWith({
    Board? board,
    List<Player>? players,
    int? currentTurn,
    int? diceValue,
    bool? gameOver,
  }) {
    return GameState(
      board: board ?? this.board,
      players: players ?? this.players,
      currentTurn: currentTurn ?? this.currentTurn,
      diceValue: diceValue ?? this.diceValue,
      gameOver: gameOver ?? this.gameOver,
    );
  }
}
