class GameEvent {
  final String id;
  final String messageKey;
  final Map<String, String>? args;
  final String? playerId; // ID del jugador al que afecta el evento
  final String? type; // Tipo de evento (penalty, bonus, move, etc.)

  GameEvent({
    required this.messageKey, 
    this.args, 
    this.playerId,
    this.type,
  }) : id = DateTime.now().toIso8601String();
}
