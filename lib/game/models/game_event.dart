class GameEvent {
  final String id;
  final String messageKey;
  final Map<String, String>? args;

  GameEvent({required this.messageKey, this.args})
      : id = DateTime.now().toIso8601String();
}
