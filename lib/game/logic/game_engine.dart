import 'dart:math';
import '../models/board.dart';
import '../models/board_action.dart';
import '../models/game_event.dart';
import '../models/player.dart';

enum GamePhase { idle, rolling, choosing_token, moving, finished }

class GameEngine {
  final Board board;
  final List<Player> players;
  final Random _random = Random();
  final List<GameEvent> _events = [];
  final List<String> finisherIds = [];

  int _currentPlayerIndex = 0;
  GamePhase phase = GamePhase.idle;

  GameEngine({required this.board, required this.players});

  Player get currentPlayer => players[_currentPlayerIndex];
  List<GameEvent> get events => _events;
  int get currentPlayerIndex => _currentPlayerIndex;

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'currentPlayerIndex': _currentPlayerIndex,
    'phase': phase.index,
    'finisherIds': finisherIds,
  };

  factory GameEngine.fromSavedState(Map<String, dynamic> json, Board board) {
    final engine = GameEngine(
      board: board,
      players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
    );
    engine._currentPlayerIndex = json['currentPlayerIndex'];
    engine.phase = GamePhase.values[json['phase']];
    engine.finisherIds.addAll(List<String>.from(json['finisherIds']));
    return engine;
  }

  void setCurrentPlayerById(String id) {
    final index = players.indexWhere((p) => p.id == id);
    if (index != -1) _currentPlayerIndex = index;
  }

  int rollDice() => _random.nextInt(6) + 1;

  void registerSix(Player player, int diceValue) {
    if (diceValue == 6) {
      player.consecutiveSixes++;
    } else {
      player.consecutiveSixes = 0;
    }
  }

  bool reachedThreeSixes(Player player) => player.consecutiveSixes >= 3;

  bool penaltyThreeSixes(Player player) {
    for (var token in player.tokens) {
      if (token.position > 0 && !token.isFinished) {
        token.reset();
        break;
      }
    }
    _events.add(GameEvent(
      messageKey: 'penalty_three_sixes', 
      args: {'name': player.name}
    ));
    return true;
  }

  bool isBlocked(int cellPosition, String searchingPlayerId) {
    if (cellPosition <= 0 || cellPosition >= board.finalPosition) return false;
    bool isPrivatePath = cellPosition > 68;
    for (var player in players) {
      if (isPrivatePath && player.id != searchingPlayerId) continue;
      int count = player.tokens.where((t) => t.position == cellPosition && !t.isFinished).length;
      if (count >= 2) return true;
    }
    return false;
  }

  bool canMoveToken(Player player, int tokenId, int steps) {
    if (tokenId >= player.tokens.length) return false;
    final token = player.tokens[tokenId];
    if (token.isFinished) return false;
    int target = token.position + steps;
    if (target > board.finalPosition) return false;
    for (int i = token.position + 1; i <= target; i++) {
      if (isBlocked(i, player.id)) return false;
    }
    return true;
  }

  List<int> getMovableTokenIds(int diceValue) {
    List<int> movable = [];
    for (int i = 0; i < currentPlayer.tokens.length; i++) {
      if (canMoveToken(currentPlayer, i, diceValue)) {
        movable.add(i);
      }
    }
    return movable;
  }

  void nextTurn() {
    if (currentPlayer.isFinished) {
      if (!finisherIds.contains(currentPlayer.id)) {
        finisherIds.add(currentPlayer.id);
      }
    } else if (currentPlayer.extraTurns > 0) {
      currentPlayer.extraTurns--;
      _events.add(GameEvent(
        messageKey: 'extra_turn', 
        args: {'name': currentPlayer.name}
      ));
      phase = GamePhase.idle;
      return;
    }

    int nextIndex = _currentPlayerIndex;
    int playersCount = players.length;
    int checked = 0;

    do {
      nextIndex = (nextIndex + 1) % playersCount;
      checked++;
      final nextPlayer = players[nextIndex];
      
      int activePlayersCount = players.where((p) => !p.isFinished).length;
      if (activePlayersCount <= 1) {
        phase = GamePhase.finished;
        final lastPlayer = players.firstWhere((p) => !p.isFinished, orElse: () => players.last);
        if (!finisherIds.contains(lastPlayer.id)) {
          finisherIds.add(lastPlayer.id);
        }
        return;
      }

      if (nextPlayer.isFinished) continue;

      if (nextPlayer.mustSkipTurn) {
        nextPlayer.consumeSkip();
        _events.add(GameEvent(
          messageKey: 'skip_turn_msg', 
          args: {'name': nextPlayer.name}
        ));
        continue; 
      }

      _currentPlayerIndex = nextIndex;
      phase = GamePhase.idle;
      return;
    } while (checked < playersCount);

    phase = GamePhase.finished;
  }

  void stepForward(Player player, int tokenId) {
    final token = player.tokens[tokenId];
    if (token.position < board.finalPosition) {
      token.position++;
      if (token.position == board.finalPosition) {
        token.isFinished = true;
        if (!player.isFinished) {
          player.extraTurns++; 
          _events.add(GameEvent(
            messageKey: 'token_finished_bonus', 
            args: {'name': player.name}
          ));
        } else {
          if (!finisherIds.contains(player.id)) {
            finisherIds.add(player.id);
          }
        }
      }
    }
  }

  bool applyCellAction(Player player, int tokenId) {
    final token = player.tokens[tokenId];
    final cell = board.getCell(token.position);
    final action = cell.action;
    if (action == null) return false;

    switch (action.type) {
      case BoardActionType.goToStart:
        token.reset();
        _events.add(GameEvent(
          messageKey: 'bad_luck_home', 
          args: {'name': player.name}
        ));
        return true;
      case BoardActionType.moveTo:
        if (!isBlocked(action.targetNumber!, player.id)) {
          token.position = action.targetNumber!;
          _events.add(GameEvent(
            messageKey: 'flying_to_cell', 
            args: {'name': player.name, 'cell': token.position.toString()}
          ));
          return true;
        }
        return false;
      case BoardActionType.skipTurn:
        player.addSkip(1);
        _events.add(GameEvent(
          messageKey: 'loses_turn', 
          args: {'name': player.name}
        ));
        return false;
      case BoardActionType.rollAgain:
        player.extraTurns++;
        _events.add(GameEvent(
          messageKey: 'roll_again', 
          args: {'name': player.name}
        ));
        return false;
      default: return false;
    }
  }

  bool resolveCollisions(Player player, int tokenId) {
    final token = player.tokens[tokenId];
    if (token.isFinished) return false;
    if (isBlocked(token.position, player.id)) return false;

    bool hit = false;
    for (final other in players) {
      if (other.id == player.id) continue;
      for (final otherToken in other.tokens) {
        if (!otherToken.isFinished && otherToken.position == token.position && token.position != 0) {
          otherToken.reset();
          if (!player.isFinished) player.extraTurns++;
          _events.add(GameEvent(
            messageKey: 'captured_player', 
            args: {'name': player.name, 'other': other.name}
          ));
          hit = true;
        }
      }
    }
    return hit;
  }

  void clearEvents() => _events.clear();
}
