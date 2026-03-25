import 'dart:convert';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': position,
    'isFinished': isFinished,
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
  int lastDiceValue; // ✅ Valor individual del dado

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
    this.lastDiceValue = 1, // ✅ Inicializar en 1
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
    'lastDiceValue': lastDiceValue, // ✅ Guardar en JSON
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
      lastDiceValue: json['lastDiceValue'] ?? 1, // ✅ Cargar de JSON
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
      token.reset();
    }
    skippedTurns = 0;
    consecutiveSixes = 0;
    extraTurns = 0;
    lastDiceValue = 1;
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
      lastDiceValue: lastDiceValue,
    );
    for (int i = 0; i < tokens.length; i++) {
      p.tokens[i].position = tokens[i].position;
      p.tokens[i].isFinished = tokens[i].isFinished;
    }
    return p;
  }
}
