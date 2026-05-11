import 'dart:convert';

class XpReceipt {
  final String id;
  final int xp;
  final bool isOnline;
  final DateTime timestamp;

  XpReceipt({
    required this.id,
    required this.xp,
    required this.isOnline,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'xp': xp,
    'is_online': isOnline,
    'timestamp': timestamp.toIso8601String(),
  };

  factory XpReceipt.fromJson(Map<String, dynamic> j) => XpReceipt(
    id: j['id'] as String,
    xp: j['xp'] as int,
    isOnline: j['is_online'] as bool? ?? false,
    timestamp: DateTime.parse(j['timestamp'] as String),
  );
}

List<XpReceipt> xpReceiptsFromJson(String raw) {
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => XpReceipt.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

String xpReceiptsToJson(List<XpReceipt> receipts) =>
    jsonEncode(receipts.map((r) => r.toJson()).toList());
