import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../presence/child_repository.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import 'children_screen.dart';
import 'user_profile_screen.dart';
import 'users_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.profile,
    required this.authService,
    required this.userRepository,
    required this.childRepository,
  });

  final UserProfile profile;
  final GoogleAuthService authService;
  final UserRepository userRepository;
  final ChildRepository childRepository;

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

  void _openChildren(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChildrenScreen(
          profile: profile,
          childRepository: childRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = profile.displayName?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conecta Creche'),
        actions: [
          // Temporary entry point until the presence day view (ticket 04/07)
          // provides its own navigation to the children catalog.
          if (profile.role.canOperatePresence)
            IconButton(
              onPressed: () => _openChildren(context),
              tooltip: 'Crianças',
              icon: const Icon(Icons.child_care_outlined),
            ),
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
