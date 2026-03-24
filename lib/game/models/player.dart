class Token {
  final int id;
  int position;
  bool isFinished;
  bool isMoving;

  Token({
    required this.id,
    this.position = 0,
    this.isFinished = false,
    this.isMoving = false,
  });

  void reset() {
    position = 0;
    isFinished = false;
    isMoving = false;
  }
}

class Player {
  final String id;
  final String name;
  final String tokenAsset;
  final int index;

  final List<Token> tokens;

  int skippedTurns;
  int consecutiveSixes;
  int extraTurns;
  bool isAI;

  Player({
    required this.id,
    required this.name,
    required this.tokenAsset,
    required this.index,
    required int tokenCount,
    this.skippedTurns = 0,
    this.consecutiveSixes = 0,
    this.extraTurns = 0,
    this.isAI = false,
  }) : tokens = List.generate(tokenCount, (i) => Token(id: i));

  bool get isFinished => tokens.every((t) => t.isFinished);

  void updateFromNetwork(Map<String, dynamic> data) {
    // ✅ CORRECCIÓN: Sincronizar todos los estados del servidor
    extraTurns = data['extraTurns'] ?? extraTurns;
    skippedTurns = data['skippedTurns'] ?? skippedTurns;
    consecutiveSixes = data['consecutiveSixes'] ?? consecutiveSixes;
    isAI = data['isAI'] ?? isAI;

    final List? tokensData = data['tokens'];
    if (tokensData != null) {
      for (var tData in tokensData) {
        int tId = tData['id'] ?? 0;
        if (tId < tokens.length) {
          tokens[tId].position = tData['position'] ?? tokens[tId].position;
          tokens[tId].isFinished = tData['isFinished'] ?? tokens[tId].isFinished;
        }
      }
    }
  }

  void resetToStart() {
    for (var token in tokens) {
      token.reset();
    }
    skippedTurns = 0;
    consecutiveSixes = 0;
    extraTurns = 0;
  }

  void addSkip(int turns) => skippedTurns += turns;
  bool get mustSkipTurn => skippedTurns > 0;
  void consumeSkip() { if (skippedTurns > 0) skippedTurns--; }

  Player copy() {
    final p = Player(
      id: id,
      name: name,
      tokenAsset: tokenAsset,
      index: index,
      tokenCount: tokens.length,
      skippedTurns: skippedTurns,
      consecutiveSixes: consecutiveSixes,
      extraTurns: extraTurns,
      isAI: isAI,
    );
    for (int i = 0; i < tokens.length; i++) {
      p.tokens[i].position = tokens[i].position;
      p.tokens[i].isFinished = tokens[i].isFinished;
    }
    return p;
  }
}
