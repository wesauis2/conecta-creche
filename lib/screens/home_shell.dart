import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import 'presence_day_screen.dart';
import 'presence_gestao_screen.dart';
import 'user_profile_screen.dart';
import 'users_screen.dart';

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
    // Gestão/admin land on the aggregate presença view; cuidador keeps the
    // day view (ticket 07 will finalize role-based home routing).
    if (profile.role.canInactivateChild) {
      return PresenceGestaoScreen(
        profile: profile,
        childRepository: childRepository,
        presenceRepository: presenceRepository,
        appBarLeadingActions: [
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
    if (profile.role.canOperatePresence) {
      return PresenceDayScreen(
        profile: profile,
        childRepository: childRepository,
        presenceRepository: presenceRepository,
        appBarLeadingActions: [
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

    final greetingName = profile.displayName?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conecta Creche'),
        actions: [
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greetingName != null && greetingName.isNotEmpty
                  ? 'Olá, $greetingName!'
                  : 'Bem-vindo ao Conecta Creche',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Em breve você poderá acompanhar a rotina da creche por aqui.',
            ),
          ],
        ),
      ),
    );
  }
}
