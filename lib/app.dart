import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/google_auth_service.dart';
import 'screens/bootstrap_error_screen.dart';
import 'screens/config_missing_screen.dart';
import 'screens/signed_in_screen.dart';
import 'screens/sign_in_screen.dart';

class ConectaCrecheApp extends StatelessWidget {
  const ConectaCrecheApp({
    super.key,
    required this.authService,
    this.bootstrapError,
  });

  final GoogleAuthService authService;
  final Object? bootstrapError;

  @override
  Widget build(BuildContext context) {
    if (bootstrapError != null) {
      return MaterialApp(
        home: BootstrapErrorScreen(error: bootstrapError!),
      );
    }

    return MaterialApp(
      title: 'Conecta Creche',
      home: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return SignInScreen(authService: authService);
          }
          return SignedInScreen(user: user, authService: authService);
        },
      ),
    );
  }
}

class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Conecta Creche',
      home: ConfigMissingScreen(),
    );
  }
}
