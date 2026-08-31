import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import 'presence_home_body.dart';
import 'user_profile_screen.dart';
import 'users_screen.dart';

/// Thin post-login shell: owns the auth-dependent app bar shortcuts (perfil/
/// usuários) and hands role-based routing off to [PresenceHomeBody], which
/// only needs [profile] and the presence repos. Kept thin on purpose so the
/// routing logic stays testable without `GoogleAuthService`/
/// `UserRepository`. See ticket 07.
class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.profile,
    required this.authService,
    required this.userRepository,
    required this.childRepository,
    required this.presenceRepository,
  });

  final UserProfile profile;
  final GoogleAuthService authService;
  final UserRepository userRepository;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen(
          profile: profile,
          authService: authService,
          userRepository: userRepository,
        ),
      ),
    );
  }

  void _openUsers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UsersScreen(
          profile: profile,
          userRepository: userRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PresenceHomeBody(
      profile: profile,
      childRepository: childRepository,
      presenceRepository: presenceRepository,
      appBarActions: [
        if (profile.canManageUsers)
          IconButton(
            onPressed: () => _openUsers(context),
            tooltip: 'Usuários',
            icon: const Icon(Icons.group_outlined),
          ),
        IconButton(
          onPressed: () => _openProfile(context),
          tooltip: 'Meu perfil',
          icon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }
}
