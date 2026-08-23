import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder Firebase options for CI and developers without local config.
///
/// Replace by running `./sh/firebase-setup.sh` or `flutterfire configure`,
/// which writes the ignored `lib/firebase_options.dart`.
class DefaultFirebaseOptions {
  static const String stubProjectId = 'STUB_NOT_CONFIGURED';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase web não está configurado nesta semana.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Plataforma não suportada: $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'STUB',
    appId: '1:STUB:android:STUB',
    messagingSenderId: 'STUB',
    projectId: stubProjectId,
  );
}
