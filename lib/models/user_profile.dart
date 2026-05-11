import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int xp;
  final int level;
  final int wins;
  final int matchesPlayed;
  final int tokensCapture;
  // 'google' = use Google profile photo; 'icon' = use a predefined icon
  final String avatarType;
  final String? avatarIconId;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.xp = 0,
    this.level = 1,
    this.wins = 0,
    this.matchesPlayed = 0,
    this.tokensCapture = 0,
    this.avatarType = 'google',
    this.avatarIconId,
  });

  bool get usesCustomIcon => avatarType == 'icon' && avatarIconId != null;

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: data['display_name'] as String? ?? '',
      photoUrl: data['photo_url'] as String?,
      xp: data['xp'] as int? ?? 0,
      level: data['level'] as int? ?? 1,
      wins: data['wins'] as int? ?? 0,
      matchesPlayed: data['matches_played'] as int? ?? 0,
      tokensCapture: data['tokens_capture'] as int? ?? 0,
      avatarType: data['avatar_type'] as String? ?? 'google',
      avatarIconId: data['avatar_icon_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'display_name': displayName,
    'photo_url': photoUrl,
    'xp': xp,
    'level': level,
    'wins': wins,
    'matches_played': matchesPlayed,
    'tokens_capture': tokensCapture,
    'avatar_type': avatarType,
    'avatar_icon_id': avatarIconId,
    'updated_at': FieldValue.serverTimestamp(),
  };

  static const Object _unset = Object();

  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    int? xp,
    int? level,
    int? wins,
    int? matchesPlayed,
    int? tokensCapture,
    String? avatarType,
    Object? avatarIconId = _unset,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      wins: wins ?? this.wins,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      tokensCapture: tokensCapture ?? this.tokensCapture,
      avatarType: avatarType ?? this.avatarType,
      avatarIconId: identical(avatarIconId, _unset)
          ? this.avatarIconId
          : avatarIconId as String?,
    );
  }
}
