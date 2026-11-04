import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/avatar_icons.dart';
import '../models/user_profile.dart';

class UserAvatarWidget extends StatelessWidget {
  final UserProfile? profile;
  final User? firebaseUser;
  final double radius;

  const UserAvatarWidget({
    super.key,
    required this.profile,
    this.firebaseUser,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (profile?.usesCustomIcon == true) {
      final icon = avatarIconById(profile!.avatarIconId);
      if (icon != null) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: icon.color,
          child: Icon(icon.icon, color: Colors.white, size: radius * 1.1),
        );
      }
    }

    final photoUrl = profile?.photoUrl ?? firebaseUser?.photoURL;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: Colors.orange.shade800,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.orange.shade800,
      child: Icon(Icons.person, color: Colors.white, size: radius * 0.9),
    );
  }
}
