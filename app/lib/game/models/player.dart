
class Token {
  final int id;
  int _position;
  bool _isFinished;
  bool isMoving;

  Token({
    required this.id,
    int position = 0,
    bool isFinished = false,
    this.isMoving = false,
  })  : _position = position,
        _isFinished = isFinished;

  // ✅ Getters
  int get position => _position;
  bool get isFinished => _isFinished;

  // ✅ Setters con candado
  set position(int val) {
    if (_isFinished && val != -1) return; // Si terminó, solo aceptamos -1
    _position = val;
  }

  set isFinished(bool val) {
    if (_isFinished && !val) return; // Una vez true, no puede volver a false (excepto reset total)
    _isFinished = val;
  }

  void reset() {
    if (_isFinished) return; // No se puede capturar una ficha terminada
    _position = 0;
    _isFinished = false;
    isMoving = false;
  }

  // Para reinicio completo de partida
  void forceReset() {
    _position = 0;
    _isFinished = false;
    isMoving = false;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': _position,
    'isFinished': _isFinished,
  };

  factory Token.fromJson(Map<String, dynamic> json) => Token(
    id: json['id'],
    position: json['position'],
    isFinished: json['isFinished'],
  );
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
  bool isAutoPlaying;
  bool isConnected;
  int lastDiceValue;
  String avatarType;
  String? avatarIconId;

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
    this.isAutoPlaying = false,
    this.isConnected = true,
    this.lastDiceValue = 1,
    this.avatarType = 'google',
    this.avatarIconId,
  }) : tokens = List.generate(tokenCount, (i) => Token(id: i));

  bool get isFinished => tokens.every((t) => t.isFinished);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tokenAsset': tokenAsset,
    'index': index,
    'skippedTurns': skippedTurns,
    'consecutiveSixes': consecutiveSixes,
    'extraTurns': extraTurns,
    'isAI': isAI,
    'isAutoPlaying': isAutoPlaying,
    'isConnected': isConnected,
    'lastDiceValue': lastDiceValue,
    'avatarType': avatarType,
    'avatarIconId': avatarIconId,
    'tokens': tokens.map((t) => t.toJson()).toList(),
  };

  factory Player.fromJson(Map<String, dynamic> json) {
    final player = Player(
      id: json['id'],
      name: json['name'],
      tokenAsset: json['tokenAsset'],
      index: json['index'],
      tokenCount: (json['tokens'] as List).length,
      skippedTurns: json['skippedTurns'],
      consecutiveSixes: json['consecutiveSixes'],
      extraTurns: json['extraTurns'],
      isAI: json['isAI'],
      isAutoPlaying: json['isAutoPlaying'] ?? false,
      isConnected: json['isConnected'] ?? true,
      lastDiceValue: json['lastDiceValue'] ?? 1,
      avatarType: json['avatarType'] as String? ?? 'google',
      avatarIconId: json['avatarIconId'] as String?,
    );
    final List tokensJson = json['tokens'];
    for (int i = 0; i < tokensJson.length; i++) {
      player.tokens[i].position = tokensJson[i]['position'];
      player.tokens[i].isFinished = tokensJson[i]['isFinished'];
    }
    return player;
  }

  void resetToStart() {
    for (var token in tokens) {
      token.forceReset();
    }
    skippedTurns = 0;
    consecutiveSixes = 0;
    extraTurns = 0;
    lastDiceValue = 1;
    isAutoPlaying = false;
    isConnected = true;
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
      isAutoPlaying: isAutoPlaying,
      isConnected: isConnected,
      lastDiceValue: lastDiceValue,
      avatarType: avatarType,
      avatarIconId: avatarIconId,
    );
    for (int i = 0; i < tokens.length; i++) {
      p.tokens[i].position = tokens[i].position;
      p.tokens[i].isFinished = tokens[i].isFinished;
    }
    return p;
  }
}
