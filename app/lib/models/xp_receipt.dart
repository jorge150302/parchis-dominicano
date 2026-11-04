import 'dart:convert';

class XpReceipt {
  final String id;
  final int xp;
  final bool isOnline;
  final DateTime timestamp;

  /// True when the receipt records a played match (stats below apply), as
  /// opposed to an XP-only grant such as a guest migration chunk.
  final bool isMatch;
  final bool isWin;
  final int captures;

  XpReceipt({
    required this.id,
    required this.xp,
    required this.isOnline,
    required this.timestamp,
    this.isMatch = false,
    this.isWin = false,
    this.captures = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'xp': xp,
    'is_online': isOnline,
    'timestamp': timestamp.toIso8601String(),
    if (isMatch) 'match': true,
    if (isWin) 'win': true,
    if (captures > 0) 'captures': captures,
  };

  factory XpReceipt.fromJson(Map<String, dynamic> j) => XpReceipt(
    id: j['id'] as String,
    xp: j['xp'] as int,
    isOnline: j['is_online'] as bool? ?? false,
    timestamp: DateTime.parse(j['timestamp'] as String),
    isMatch: j['match'] as bool? ?? false,
    isWin: j['win'] as bool? ?? false,
    captures: j['captures'] as int? ?? 0,
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
