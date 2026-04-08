import 'package:uuid/uuid.dart';

class GameEvent {
  final String id;
  final String messageKey;
  final Map<String, String>? args;
  final String? playerId; 
  final String? type; 

  GameEvent({
    required this.messageKey, 
    this.args, 
    this.playerId,
    this.type,
  }) : id = const Uuid().v4(); // ✅ ID único garantizado para que Flutter no ignore mensajes
}
