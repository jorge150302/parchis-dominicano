import 'package:flutter/material.dart';

import '../models/avatar_icons.dart';
import '../service/auth_service.dart';
import 'user_avatar_widget.dart';

Future<void> showAvatarSelectorSheet(BuildContext context, AuthService auth) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: _AvatarSelectorSheet(auth: auth),
      ),
    ),
  );
}

class _AvatarSelectorSheet extends StatelessWidget {
  final AuthService auth;

  const _AvatarSelectorSheet({required this.auth});

  @override
  Widget build(BuildContext context) {
    final currentType = auth.profile?.avatarType ?? 'google';
    final currentIconId = auth.profile?.avatarIconId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose Avatar',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── Google photo option ───────────────────────────────────────────
          _SelectorRow(
            selected: currentType == 'google',
            onTap: () {
              auth.updateAvatar('google');
              Navigator.pop(context);
            },
            child: Row(
              children: [
                UserAvatarWidget(
                  profile: auth.profile?.copyWith(avatarType: 'google'),
                  firebaseUser: auth.firebaseUser,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                const Text('Google photo', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Icon grid ─────────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: kAvatarIcons.length,
            itemBuilder: (_, i) {
              final icon = kAvatarIcons[i];
              final selected = currentType == 'icon' && currentIconId == icon.id;
              return GestureDetector(
                onTap: () {
                  auth.updateAvatar('icon', iconId: icon.id);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Colors.orangeAccent, width: 2.5)
                        : null,
                  ),
                  child: CircleAvatar(
                    backgroundColor: icon.color,
                    child: Icon(icon.icon, color: Colors.white, size: 22),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectorRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectorRow({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.orangeAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
          color: selected ? Colors.orange.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: child,
      ),
    );
  }
}
