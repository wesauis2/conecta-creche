import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth/google_auth_service.dart';
import 'auth/user_sync_gate.dart';
import 'forms/form_question_repository.dart';
import 'mural/mural_reads_repository.dart';
import 'mural/mural_repository.dart';
import 'mural/notification_repository.dart';
import 'presence/child_repository.dart';
import 'presence/presence_repository.dart';
import 'screens/bootstrap_error_screen.dart';
import 'screens/config_missing_screen.dart';
import 'screens/signed_in_screen.dart';
import 'screens/sign_in_screen.dart';
import 'users/user_repository.dart';

class ConectaCrecheApp extends StatelessWidget {
  ConectaCrecheApp({
    super.key,
    required this.authService,
    required this.userRepository,
    ChildRepository? childRepository,
    PresenceRepository? presenceRepository,
    FormQuestionRepository? formQuestionRepository,
    MuralRepository? muralRepository,
    NotificationRepository? notificationRepository,
    MuralReadsRepository? muralReadsRepository,
    this.bootstrapError,
  })  : childRepository = childRepository ?? ChildRepository(),
        presenceRepository = presenceRepository ?? PresenceRepository(),
        formQuestionRepository =
            formQuestionRepository ?? FormQuestionRepository(),
        muralRepository = muralRepository ?? MuralRepository(),
        notificationRepository =
            notificationRepository ?? NotificationRepository(),
        muralReadsRepository =
            muralReadsRepository ?? MuralReadsRepositoryImpl();

  final GoogleAuthService authService;
  final UserRepository userRepository;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;
  final FormQuestionRepository formQuestionRepository;
  final MuralPostsRepository muralRepository;
  final NotificationsRepository notificationRepository;
  final MuralReadsRepository muralReadsRepository;
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
          return UserSyncGate(
            user: user,
            userRepository: userRepository,
            child: SignedInScreen(
              user: user,
              authService: authService,
              userRepository: userRepository,
              childRepository: childRepository,
              presenceRepository: presenceRepository,
              formQuestionRepository: formQuestionRepository,
              muralRepository: muralRepository,
              notificationRepository: notificationRepository,
              muralReadsRepository: muralReadsRepository,
            ),
          );
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
