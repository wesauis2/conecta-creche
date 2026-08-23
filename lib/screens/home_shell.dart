import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import 'user_profile_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.profile,
    required this.authService,
    required this.userRepository,
  });

  final UserProfile profile;
  final GoogleAuthService authService;
  final UserRepository userRepository;

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

  @override
  Widget build(BuildContext context) {
    final greetingName = profile.displayName?.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conecta Creche'),
        actions: [
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
