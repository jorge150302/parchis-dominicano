class GameEvent {
  final String id;
  final String message;

  GameEvent({required this.message}) : id = DateTime.now().toIso8601String();
}
