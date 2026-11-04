import 'board.dart';
import 'rules.dart';

/// A token as the rules see it. Position 0 is home; a finished token has
/// `isFinished == true` and position -1.
abstract interface class RulesToken {
  int get id;
  int get position;
  set position(int value);
  bool get isFinished;
  set isFinished(bool value);
}

/// A player as the rules see it. The app and the server keep their own
/// player classes (avatars, connection state…) and implement this.
abstract interface class RulesPlayer {
  String get id;
  List<RulesToken> get tokens;
  abstract int skippedTurns;
  abstract int consecutiveSixes;
  abstract int extraTurns;
  bool get isFinished;
}

/// A token the rules sent home, and the cell it was on.
class SentHome {
  SentHome(this.token, this.fromPosition);
  final RulesToken token;
  final int fromPosition;
}

class RollOutcome {
  RollOutcome._({
    required this.dice,
    this.threeSixes = false,
    this.sentHome = const [],
    this.movable = const [],
    this.playAgain = false,
  });

  final int dice;

  /// The third consecutive 6: the penalty was applied and the turn is over.
  final bool threeSixes;

  /// Tokens the three-sixes penalty sent home.
  final List<SentHome> sentHome;

  /// Tokens that can move [dice] cells. Empty when the roll is lost.
  final List<RulesToken> movable;

  /// Only when [movable] is empty: the player rolls again (a 6, or a pending
  /// extra turn) instead of passing the turn.
  final bool playAgain;

  bool get canMove => movable.isNotEmpty;
}

class Capture<P extends RulesPlayer> {
  Capture(this.owner, this.token, this.fromPosition);
  final P owner;
  final RulesToken token;
  final int fromPosition;
}

class LandingOutcome<P extends RulesPlayer> {
  /// The cell the dice took the token to (before any cell action).
  int landedOn = 0;

  /// The action of [landedOn], applied unless [skipCancelledBySix].
  BoardAction? cellAction;

  /// A 6 landing on "skip turn": neither the skip nor the 6's extra turn.
  bool skipCancelledBySix = false;

  /// A jump whose destination is a bridge (D4): the token stayed.
  bool jumpBlocked = false;

  /// The token was sent home by a "go to start" cell, from [landedOn].
  bool sentHomeByCell = false;

  final List<Capture<P>> captures = [];

  /// The token reached home on this move (by steps or by a jump).
  bool tokenFinished = false;

  /// [tokenFinished] earned the finish bonus (D2).
  bool finishBonus = false;

  /// This move finished the player's last token.
  bool playerFinished = false;

  /// The match ended with this move.
  bool gameOver = false;

  /// The same player rolls again (an extra turn was spent).
  bool playAgain = false;
}

class TurnAdvance<P extends RulesPlayer> {
  TurnAdvance(this.skipped, {this.gameOver = false});

  /// Players whose turn was skipped, in order, each spending one skip.
  final List<P> skipped;
  final bool gameOver;
}

/// The turn engine shared by the app and the server. It owns the rules, not
/// the timing: callers roll the die, animate, and call [roll], [step] /
/// [land] (or [move]) and [nextTurn] in that order.
class ParchisEngine<P extends RulesPlayer> {
  ParchisEngine({
    required this.board,
    required this.players,
    this.rules = RulesConfig.official,
  });

  final Board board;
  final List<P> players;
  final RulesConfig rules;

  /// Players in finishing order; complete once [isOver].
  final List<P> finishOrder = [];

  int currentIndex = 0;
  bool isOver = false;

  P get current => players[currentIndex];

  /// Whether a bridge on [position] stops [mover] (D3).
  bool isBlocked(int position, RulesPlayer mover) {
    if (rules.bridges == BridgeRule.none) return false;
    if (position <= 0 || position >= board.finalPosition) return false;
    for (final player in players) {
      final count = player.tokens
          .where((t) => !t.isFinished && t.position == position)
          .length;
      if (count < 2) continue;
      if (rules.bridges == BridgeRule.blocksEveryone) return true;
      if (player.id != mover.id) return true;
    }
    return false;
  }

  /// Exact roll to finish; bridges can be neither crossed nor landed on.
  bool canMove(RulesPlayer player, RulesToken token, int steps) {
    if (token.isFinished || steps < 1) return false;
    if (token.position + steps > board.finalPosition) return false;
    for (var i = 1; i <= steps; i++) {
      if (isBlocked(token.position + i, player)) return false;
    }
    return true;
  }

  List<RulesToken> movableTokens(RulesPlayer player, int steps) =>
      [for (final t in player.tokens) if (canMove(player, t, steps)) t];

  /// Applies a roll of [dice] by the current player.
  RollOutcome roll(int dice) {
    final player = current;
    if (dice == 6) {
      player.consecutiveSixes++;
      if (player.consecutiveSixes >= 3) {
        player.consecutiveSixes = 0;
        player.extraTurns = 0;
        return RollOutcome._(
          dice: dice,
          threeSixes: true,
          sentHome: _threeSixesPenalty(player),
        );
      }
      // The 6's extra turn (R6), spent after this move or right away.
      player.extraTurns++;
    } else {
      player.consecutiveSixes = 0;
    }

    final movable = movableTokens(player, dice);
    if (movable.isNotEmpty) return RollOutcome._(dice: dice, movable: movable);
    return RollOutcome._(dice: dice, playAgain: _spendExtraTurn(player));
  }

  List<SentHome> _threeSixesPenalty(RulesPlayer player) {
    final onTrack =
        player.tokens.where((t) => !t.isFinished && t.position > 0).toList();
    final sent = switch (rules.threeSixes) {
      ThreeSixesPenalty.oneTokenHome => onTrack.take(1).toList(),
      ThreeSixesPenalty.allTokensHome => onTrack,
      ThreeSixesPenalty.loseTurn => <RulesToken>[],
    };
    final out = [for (final t in sent) SentHome(t, t.position)];
    for (final t in sent) {
      t.position = 0;
    }
    return out;
  }

  /// Moves [token] one cell; true when that step finished it.
  bool step(RulesToken token) {
    if (token.isFinished || token.position >= board.finalPosition) {
      return false;
    }
    token.position++;
    if (token.position >= board.finalPosition) {
      _finishToken(token);
      return true;
    }
    return false;
  }

  void _finishToken(RulesToken token) {
    token.isFinished = true;
    token.position = -1;
  }

  /// Resolves [token]'s landing after [dice] steps: cell action, captures,
  /// finish, and whether the player rolls again.
  LandingOutcome<P> land(P player, RulesToken token, int dice) {
    final out = LandingOutcome<P>();
    if (token.isFinished) {
      out.tokenFinished = true;
      out.landedOn = board.finalPosition;
      if (rules.finishBonus && !player.isFinished) {
        player.extraTurns++;
        out.finishBonus = true;
      }
    } else {
      out.landedOn = token.position;
      _applyCell(player, token, dice, out);
      _resolveCaptures(player, token, out);
    }

    if (player.isFinished) {
      out.playerFinished = true;
      player.extraTurns = 0;
      if (!finishOrder.contains(player)) finishOrder.add(player);
      _checkGameOver();
    }
    out.gameOver = isOver;
    out.playAgain = !isOver && _spendExtraTurn(player);
    return out;
  }

  void _applyCell(
      P player, RulesToken token, int dice, LandingOutcome<P> out) {
    final action = board.getCellSafe(token.position)?.action;
    out.cellAction = action;
    if (action == null) return;

    switch (action.type) {
      case BoardActionType.skipTurn:
        if (dice == 6) {
          // R9: the skip and the 6's extra turn cancel out.
          out.skipCancelledBySix = true;
          if (player.extraTurns > 0) player.extraTurns--;
        } else {
          player.skippedTurns++;
        }
      case BoardActionType.goToStart:
        token.position = 0;
        out.sentHomeByCell = true;
      case BoardActionType.rollAgain:
        player.extraTurns++;
      case BoardActionType.moveTo:
        final target = action.targetNumber!;
        if (rules.jumpsRespectBridges && isBlocked(target, player)) {
          out.jumpBlocked = true;
          return;
        }
        token.position = target;
        if (target >= board.finalPosition) {
          _finishToken(token);
          out.tokenFinished = true;
          if (rules.finishBonus &&
              rules.finishBonusOnJump &&
              !player.isFinished) {
            player.extraTurns++;
            out.finishBonus = true;
          }
        }
    }
  }

  void _resolveCaptures(P player, RulesToken token, LandingOutcome<P> out) {
    if (token.isFinished || token.position <= 0) return;
    for (final other in players) {
      if (other.id == player.id) continue;
      for (final t in other.tokens) {
        if (t.isFinished || t.position != token.position) continue;
        out.captures.add(Capture(other, t, t.position));
        t.position = 0;
        player.extraTurns++; // R7: one extra turn per captured token.
      }
    }
  }

  /// [step]s [token] [dice] cells, then [land]s it.
  LandingOutcome<P> move(P player, RulesToken token, int dice) {
    for (var i = 0; i < dice; i++) {
      if (step(token)) break;
    }
    return land(player, token, dice);
  }

  bool _spendExtraTurn(RulesPlayer player) {
    if (player.isFinished || player.extraTurns <= 0) return false;
    player.extraTurns--;
    return true;
  }

  void _checkGameOver() {
    final remaining = players.where((p) => !p.isFinished).toList();
    final over = switch (rules.endCondition) {
      EndCondition.lastStanding => remaining.length <= 1,
      EndCondition.firstFinisher => finishOrder.isNotEmpty,
    };
    if (over) _endGame();
  }

  void _endGame() {
    if (isOver) return;
    isOver = true;
    final rest = players.where((p) => !finishOrder.contains(p)).toList()
      ..sort((a, b) => progress(b).compareTo(progress(a)));
    finishOrder.addAll(rest);
  }

  /// Cells covered by [player]'s tokens, finished tokens counting in full.
  int progress(RulesPlayer player) => player.tokens.fold(
      0, (sum, t) => sum + (t.isFinished ? board.finalPosition : t.position));

  /// Passes the turn to the next player who is still playing, spending
  /// pending skips on the way.
  TurnAdvance<P> nextTurn() {
    if (rules.sixesCountPerTurn) current.consecutiveSixes = 0;
    if (!isOver) _checkGameOver();
    if (isOver) return TurnAdvance(const [], gameOver: true);

    final active = players.where((p) => !p.isFinished).toList();
    // Everyone owes a skip: cancel one each silently instead of skipping
    // the whole table in turn.
    if (active.every((p) => p.skippedTurns > 0)) {
      for (final p in active) {
        p.skippedTurns--;
      }
    }

    final skipped = <P>[];
    while (true) {
      currentIndex = (currentIndex + 1) % players.length;
      final p = current;
      if (p.isFinished) continue;
      if (p.skippedTurns > 0) {
        p.skippedTurns--;
        skipped.add(p);
        continue;
      }
      return TurnAdvance(skipped);
    }
  }
}
