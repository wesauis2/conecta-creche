import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';

class SignedInScreen extends StatelessWidget {
  const SignedInScreen({
    super.key,
    required this.user,
    required this.authService,
  });

  final User user;
  final GoogleAuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conecta Creche')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sessão Firebase ativa',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('UID: ${user.uid}'),
            if (user.email != null) Text('E-mail: ${user.email}'),
            if (user.displayName != null)
              Text('Nome: ${user.displayName}'),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => authService.signOut(),
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
