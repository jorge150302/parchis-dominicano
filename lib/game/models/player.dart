class Player {
  final String id;
  final String name;
  final String tokenAsset;
  final int index; // 🎨 Slot fijo enviado por el servidor (0-3)
  int position;
  int skippedTurns;
  int consecutiveSixes;
  int extraTurns;
  bool isFinished;
  bool isMoving;
  int stepsMoved;
  bool isAI;

  Player({
    required this.id,
    required this.name,
    required this.tokenAsset,
    required this.index,
    this.position = 0,
    this.skippedTurns = 0,
    this.consecutiveSixes = 0,
    this.extraTurns = 0,
    this.isFinished = false,
    this.isMoving = false,
    this.stepsMoved = 0,
    this.isAI = false,
  });

  void updateFromNetwork(Map<String, dynamic> data) {
    position = data['position'] ?? position;
    isFinished = data['isFinished'] ?? isFinished;
    isAI = data['isAI'] ?? isAI;
  }

  void resetToStart() {
    position = 0;
    skippedTurns = 0;
    consecutiveSixes = 0;
    extraTurns = 0;
    isFinished = false;
    isMoving = false;
    stepsMoved = 0;
  }

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

  bool get mustSkipTurn => skippedTurns > 0;

  void consumeSkip() {
    if (skippedTurns > 0) skippedTurns--;
  }

  Player copy() {
    return Player(
      id: id,
      name: name,
      tokenAsset: tokenAsset,
      index: index,
      position: position,
      skippedTurns: skippedTurns,
      consecutiveSixes: consecutiveSixes,
      extraTurns: extraTurns,
      isFinished: isFinished,
      isMoving: isMoving,
      stepsMoved: stepsMoved,
      isAI: isAI,
    );
  }
}
