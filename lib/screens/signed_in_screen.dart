import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import 'home_shell.dart';
import 'pending_approval_screen.dart';

class SignedInScreen extends StatelessWidget {
  const SignedInScreen({
    super.key,
    required this.user,
    required this.authService,
    required this.userRepository,
    required this.childRepository,
    required this.presenceRepository,
  });

  final User user;
  final GoogleAuthService authService;
  final UserRepository userRepository;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: userRepository.watchProfile(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Conecta Creche')),
            body: const Center(
              child: Text('Não foi possível carregar seu perfil.'),
            ),
          );
        }

        if (profile.isPendingApproval) {
          return PendingApprovalScreen(
            profile: profile,
            authService: authService,
            userRepository: userRepository,
          );
        }

        return HomeShell(
          profile: profile,
          authService: authService,
          userRepository: userRepository,
          childRepository: childRepository,
          presenceRepository: presenceRepository,
        );
      },
    );
  }
}
