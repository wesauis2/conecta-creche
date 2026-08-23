import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import 'user_profile_screen.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({
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
    return Scaffold(
      appBar: AppBar(title: const Text('Conecta Creche')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.hourglass_top,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Aguardando liberação',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sua conta foi criada, mas ainda não foi vinculada à creche. '
              'Um gestor precisa liberar seu acesso antes que você possa usar o aplicativo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => _openProfile(context),
              icon: const Icon(Icons.person_outline),
              label: const Text('Meu perfil'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: authService.signOut,
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
