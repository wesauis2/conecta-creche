import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/google_auth_service.dart';
import 'classes/class_repository.dart';
import 'fcm/fcm_messaging_service.dart';
import 'fcm/fcm_sender.dart';
import 'fcm/fcm_token_repository.dart';
import 'fcm/notification_dispatch_service.dart';
import 'firebase/firebase_bootstrap.dart';
import 'forms/form_question_repository.dart';
import 'levels/level_repository.dart';
import 'mural/mural_reads_repository.dart';
import 'mural/mural_repository.dart';
import 'mural/notification_repository.dart';
import 'presence/child_repository.dart';
import 'presence/presence_repository.dart';
import 'users/user_repository.dart';

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
          userRepository: UserRepository(),
          bootstrapError: bootstrap.error,
        ),
      );
      return;
    case FirebaseBootstrapState.initialized:
      FcmMessagingService.bindBackgroundHandler();

      final authService = GoogleAuthService();
      final userRepository = UserRepository();
      final childRepository = ChildRepository();
      final formQuestionRepository = FormQuestionRepository();
      final levelRepository = LevelRepository();
      final classRepository = ClassRepository();
      final notificationRepository = NotificationRepository();
      final muralReadsRepository = MuralReadsRepositoryImpl();
      final fcmTokenRepository = FcmTokenRepository();
      // Cliente não tem Admin: grava feed e degrada o push (script lab envia).
      final notificationDispatch = NotificationDispatchService(
        notifications: notificationRepository,
        tokens: fcmTokenRepository,
        children: childRepository,
        sender: const NoOpFcmSender(),
      );
      final presenceRepository = PresenceRepository(
        notificationDispatch: notificationDispatch,
      );
      final muralRepository = MuralRepository(
        notificationDispatch: notificationDispatch,
      );
      final fcmMessagingService = FcmMessagingService(
        tokenRepository: fcmTokenRepository,
      );
      fcmMessagingService.attachToAuth(authService.authStateChanges);

      await authService.ensureGoogleSignInInitialized();
      runApp(
        ConectaCrecheApp(
          authService: authService,
          userRepository: userRepository,
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          formQuestionRepository: formQuestionRepository,
          levelRepository: levelRepository,
          classRepository: classRepository,
          muralRepository: muralRepository,
          notificationRepository: notificationRepository,
          muralReadsRepository: muralReadsRepository,
        ),
      );
  }
}
