import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum FirebaseBootstrapState {
  missingConfig,
  initialized,
  failed,
}

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({
    required this.state,
    this.error,
  });

  final FirebaseBootstrapState state;
  final Object? error;
}

bool _isMissingConfigError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('no firebase app') ||
      message.contains('not configured') ||
      message.contains('default firebaseapp') ||
      message.contains('failed to load firebaseoptions') ||
      message.contains('google-services.json') ||
      message.contains('googleservice-info.plist');
}

Future<FirebaseBootstrapResult> bootstrapFirebase() async {
  if (kIsWeb) {
    return const FirebaseBootstrapResult(
      state: FirebaseBootstrapState.missingConfig,
    );
  }

  try {
    if (Firebase.apps.isNotEmpty) {
      return const FirebaseBootstrapResult(
        state: FirebaseBootstrapState.initialized,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        // Uses google-services.json / GoogleService-Info.plist bundled in the
        // native app. lib/firebase_options.dart is optional on mobile this week.
        await Firebase.initializeApp();
        return const FirebaseBootstrapResult(
          state: FirebaseBootstrapState.initialized,
        );
      default:
        return const FirebaseBootstrapResult(
          state: FirebaseBootstrapState.missingConfig,
        );
    }
  } on Object catch (error) {
    if (_isMissingConfigError(error)) {
      return const FirebaseBootstrapResult(
        state: FirebaseBootstrapState.missingConfig,
      );
    }
    return FirebaseBootstrapResult(
      state: FirebaseBootstrapState.failed,
      error: error,
    );
  }
}
