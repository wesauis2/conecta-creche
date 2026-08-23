import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/google_auth_service.dart';
import 'firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await bootstrapFirebase();
  switch (bootstrap.state) {
    case FirebaseBootstrapState.missingConfig:
      runApp(const ConfigMissingApp());
      return;
    case FirebaseBootstrapState.failed:
      runApp(
        ConectaCrecheApp(
          authService: GoogleAuthService(),
          bootstrapError: bootstrap.error,
        ),
      );
      return;
    case FirebaseBootstrapState.initialized:
      final authService = GoogleAuthService();
      await authService.ensureGoogleSignInInitialized();
      runApp(ConectaCrecheApp(authService: authService));
  }
}
