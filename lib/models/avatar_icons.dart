import 'package:flutter/material.dart';

class AvatarIcon {
  final String id;
  final IconData icon;
  final Color color;

  const AvatarIcon({required this.id, required this.icon, required this.color});
}

const kAvatarIcons = <AvatarIcon>[
  // ── Nature / Animals ─────────────────────────────────────────────────────
  AvatarIcon(id: 'paw',       icon: Icons.pets,                        color: Color(0xFFE65100)),
  AvatarIcon(id: 'leaf',      icon: Icons.eco,                         color: Color(0xFF2E7D32)),
  AvatarIcon(id: 'bug',       icon: Icons.bug_report,                  color: Color(0xFF558B2F)),
  AvatarIcon(id: 'wave',      icon: Icons.water,                       color: Color(0xFF0277BD)),
  AvatarIcon(id: 'mountain',  icon: Icons.landscape,                   color: Color(0xFF4E342E)),
  AvatarIcon(id: 'sun',       icon: Icons.wb_sunny,                    color: Color(0xFFF57F17)),

  // ── Power / Action ────────────────────────────────────────────────────────
  AvatarIcon(id: 'bolt',      icon: Icons.bolt,                        color: Color(0xFF1565C0)),
  AvatarIcon(id: 'fire',      icon: Icons.local_fire_department,       color: Color(0xFFBF360C)),
  AvatarIcon(id: 'rocket',    icon: Icons.rocket_launch,               color: Color(0xFF1A237E)),
  AvatarIcon(id: 'target',    icon: Icons.gps_fixed,                   color: Color(0xFFB71C1C)),
  AvatarIcon(id: 'flash',     icon: Icons.flash_on,                    color: Color(0xFFF9A825)),
  AvatarIcon(id: 'speed',     icon: Icons.speed,                       color: Color(0xFF006064)),

  // ── Status / Achievement ──────────────────────────────────────────────────
  AvatarIcon(id: 'star',      icon: Icons.star,                        color: Color(0xFFFF8F00)),
  AvatarIcon(id: 'trophy',    icon: Icons.emoji_events,                color: Color(0xFF827717)),
  AvatarIcon(id: 'shield',    icon: Icons.security,                    color: Color(0xFF1B5E20)),
  AvatarIcon(id: 'crown',     icon: Icons.workspace_premium,           color: Color(0xFF6A1B9A)),
  AvatarIcon(id: 'diamond',   icon: Icons.diamond,                     color: Color(0xFF006064)),
  AvatarIcon(id: 'medal',     icon: Icons.military_tech,               color: Color(0xFF4E342E)),

  // ── Game ──────────────────────────────────────────────────────────────────
  AvatarIcon(id: 'game',      icon: Icons.sports_esports,              color: Color(0xFF4A148C)),
  AvatarIcon(id: 'dice',      icon: Icons.casino,                      color: Color(0xFF880E4F)),
  AvatarIcon(id: 'puzzle',    icon: Icons.extension,                   color: Color(0xFF00695C)),
  AvatarIcon(id: 'sword',     icon: Icons.sports_martial_arts,         color: Color(0xFF37474F)),
  AvatarIcon(id: 'chess',     icon: Icons.grid_4x4,                    color: Color(0xFF212121)),
  AvatarIcon(id: 'flag',      icon: Icons.flag,                        color: Color(0xFFAD1457)),

  // ── Personality ───────────────────────────────────────────────────────────
  AvatarIcon(id: 'brain',     icon: Icons.psychology,                  color: Color(0xFF4527A0)),
  AvatarIcon(id: 'magic',     icon: Icons.auto_fix_high,               color: Color(0xFF283593)),
  AvatarIcon(id: 'smile',     icon: Icons.sentiment_very_satisfied,    color: Color(0xFF00897B)),
  AvatarIcon(id: 'cool',      icon: Icons.sentiment_satisfied_alt,     color: Color(0xFF1976D2)),
  AvatarIcon(id: 'ghost',     icon: Icons.face_retouching_natural,     color: Color(0xFF6A1B9A)),
  AvatarIcon(id: 'alien',     icon: Icons.smart_toy,                   color: Color(0xFF00695C)),

  // ── Tech ──────────────────────────────────────────────────────────────────
  AvatarIcon(id: 'code',      icon: Icons.code,                        color: Color(0xFF0D47A1)),
  AvatarIcon(id: 'wifi',      icon: Icons.wifi,                        color: Color(0xFF00838F)),
  AvatarIcon(id: 'globe',     icon: Icons.public,                      color: Color(0xFF1565C0)),
  AvatarIcon(id: 'eye',       icon: Icons.visibility,                  color: Color(0xFF283593)),
  AvatarIcon(id: 'music',     icon: Icons.music_note,                  color: Color(0xFFC62828)),
  AvatarIcon(id: 'camera',    icon: Icons.photo_camera,                color: Color(0xFF37474F)),
];

AvatarIcon? avatarIconById(String? id) {
  if (id == null) return null;
  for (final icon in kAvatarIcons) {
    if (icon.id == id) return icon;
  }
  return null;
}
