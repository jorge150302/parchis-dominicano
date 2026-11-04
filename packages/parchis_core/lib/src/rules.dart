/// Rule options. Each one is a decision in docs/reglas.md; [RulesConfig]'s
/// defaults are the recommended choices, so changing a decision is a
/// one-line change here.
library;

/// D1: what happens on the third consecutive 6.
enum ThreeSixesPenalty {
  /// The first token on the track goes home.
  oneTokenHome,

  /// Every token that has not finished goes home.
  allTokensHome,

  /// No token goes home; the turn just ends.
  loseTurn,
}

/// D3: who a bridge (two tokens of one player on a cell) blocks.
enum BridgeRule { blocksEveryone, blocksOpponents, none }

/// P1: when the match ends.
enum EndCondition {
  /// When only one player still has tokens on the track.
  lastStanding,

  /// When the first player finishes; the rest are ranked by progress.
  firstFinisher,
}

class RulesConfig {
  const RulesConfig({
    this.tokensPerPlayer = 2,
    this.threeSixes = ThreeSixesPenalty.oneTokenHome,
    this.finishBonus = true,
    this.finishBonusOnJump = true,
    this.bridges = BridgeRule.blocksEveryone,
    this.jumpsRespectBridges = true,
    this.sixesCountPerTurn = true,
    this.endCondition = EndCondition.lastStanding,
  });

  /// The rules both the app and the server play by.
  static const official = RulesConfig();

  /// P2.
  final int tokensPerPlayer;

  /// D1.
  final ThreeSixesPenalty threeSixes;

  /// D2: a token reaching home grants an extra turn (unless it was the
  /// player's last token).
  final bool finishBonus;

  /// D2: the bonus also applies when a jump cell lands on home.
  final bool finishBonusOnJump;

  /// D3.
  final BridgeRule bridges;

  /// D4: a jump whose destination is blocked by a bridge does not happen.
  final bool jumpsRespectBridges;

  /// D5: consecutive sixes only count within one turn.
  final bool sixesCountPerTurn;

  /// P1.
  final EndCondition endCondition;
}
