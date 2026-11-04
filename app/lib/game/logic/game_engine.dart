import 'package:parchis_core/parchis_core.dart';
import '../models/game_event.dart';
import '../models/player.dart';

export 'package:parchis_core/parchis_core.dart';

enum GamePhase { idle, rolling, choosing_token, moving, finished }

class CapturedToken {
  final int playerIndex;
  final String asset;
  final int fromPosition;
  CapturedToken({required this.playerIndex, required this.asset, required this.fromPosition});
}

/// The app's match: the shared rules engine (parchis_core) plus what only
/// the app tracks — the UI phase, the event feed and the saved game.
class GameEngine extends ParchisEngine<Player> {
  GameEngine({required super.board, required super.players, super.rules});

  final List<GameEvent> _events = [];

  /// Finishing order by id. Online it comes from the server; offline it
  /// mirrors [finishOrder].
  final List<String> finisherIds = [];

  GamePhase phase = GamePhase.idle;

  Player get currentPlayer => current;
  List<GameEvent> get events => _events;
  int get currentPlayerIndex => currentIndex;

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'currentPlayerIndex': currentIndex,
    'phase': phase.index,
    'finisherIds': finisherIds,
  };

  factory GameEngine.fromSavedState(Map<String, dynamic> json, Board board) {
    final engine = GameEngine(
      board: board,
      players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
    );
    engine.currentIndex = json['currentPlayerIndex'] ?? 0;
    engine.phase = GamePhase.values[json['phase'] ?? 0];
    engine.finisherIds.addAll(List<String>.from(json['finisherIds'] ?? []));
    for (final id in engine.finisherIds) {
      engine.finishOrder.addAll(engine.players.where((p) => p.id == id));
    }
    engine.isOver = engine.phase == GamePhase.finished;
    return engine;
  }

  void setCurrentPlayerById(String id) {
    final index = players.indexWhere((p) => p.id == id);
    if (index != -1) currentIndex = index;
  }

  bool canMoveToken(Player player, int tokenId, int steps) =>
      tokenId < player.tokens.length && canMove(player, player.tokens[tokenId], steps);

  List<int> getMovableTokenIds(int diceValue) => [
    for (final t in movableTokens(currentPlayer, diceValue)) t.id,
  ];

  /// The current player rolled [dice]; adds the penalty event on three sixes.
  RollOutcome rollDice(int dice) {
    final player = currentPlayer;
    final outcome = roll(dice);
    if (outcome.threeSixes) {
      _events.add(GameEvent(
        messageKey: 'penalty_three_sixes',
        args: {'name': player.name},
        playerId: player.id,
        type: 'penalty',
      ));
    }
    return outcome;
  }

  /// One step of [player]'s token; true when it reached home.
  bool stepToken(Player player, int tokenId) => step(player.tokens[tokenId]);

  /// Resolves the landing of [player]'s token after [dice] steps and
  /// reports it in the event feed.
  LandingOutcome<Player> landToken(Player player, int tokenId, int dice) {
    final outcome = land(player, player.tokens[tokenId], dice);
    final name = {'name': player.name};

    if (outcome.finishBonus) {
      _events.add(GameEvent(messageKey: 'token_finished_bonus', args: name, playerId: player.id, type: 'bonus'));
    }
    final action = outcome.cellAction;
    if (action != null && !outcome.skipCancelledBySix && !outcome.jumpBlocked) {
      switch (action.type) {
        case BoardActionType.goToStart:
          _events.add(GameEvent(messageKey: 'bad_luck_home', args: name, playerId: player.id, type: 'penalty'));
        case BoardActionType.moveTo:
          _events.add(GameEvent(
            messageKey: 'flying_to_cell',
            args: {...name, 'cell': player.tokens[tokenId].position.toString()},
            playerId: player.id,
            type: 'move',
          ));
        case BoardActionType.skipTurn:
          _events.add(GameEvent(messageKey: 'loses_turn', args: name, playerId: player.id, type: 'penalty'));
        case BoardActionType.rollAgain:
          _events.add(GameEvent(messageKey: 'roll_again', args: name, playerId: player.id, type: 'bonus'));
      }
    }
    for (final capture in outcome.captures) {
      _events.add(GameEvent(
        messageKey: 'captured_player',
        args: {...name, 'other': capture.owner.name},
        playerId: player.id,
        type: 'bonus',
      ));
    }
    _syncFinishers();
    return outcome;
  }

  /// Ends the current action: the same player rolls again ([playAgain]),
  /// or the turn passes, announcing skipped players.
  void endAction({required bool playAgain}) {
    if (playAgain && !isOver) {
      // A specific bonus (capture, finish, cell) already said why.
      final hasSpecificBonus = _events.any((e) =>
          e.playerId == currentPlayer.id &&
          (e.messageKey == 'captured_player' ||
              e.messageKey == 'token_finished_bonus' ||
              e.messageKey == 'roll_again'));
      if (!hasSpecificBonus) {
        _events.add(GameEvent(
          messageKey: 'extra_turn',
          args: {'name': currentPlayer.name},
          playerId: currentPlayer.id,
          type: 'bonus',
        ));
      }
      phase = GamePhase.idle;
      return;
    }

    final advance = nextTurn();
    for (final p in advance.skipped) {
      _events.add(GameEvent(messageKey: 'skip_turn_msg', args: {'name': p.name}, playerId: p.id, type: 'penalty'));
    }
    _syncFinishers();
    phase = advance.gameOver ? GamePhase.finished : GamePhase.idle;
  }

  void _syncFinishers() {
    for (final p in finishOrder) {
      if (!finisherIds.contains(p.id)) finisherIds.add(p.id);
    }
  }

  void clearEvents() => _events.clear();
}
