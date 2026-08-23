import 'package:firebase_core/firebase_core.dart';

import '../firebase_options_stub.dart' as stub;
import 'app_firebase_options.dart';

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

bool get isFirebaseConfigured =>
    DefaultFirebaseOptions.currentPlatform.projectId !=
    stub.DefaultFirebaseOptions.stubProjectId;

Future<FirebaseBootstrapResult> bootstrapFirebase() async {
  if (!isFirebaseConfigured) {
    return const FirebaseBootstrapResult(
      state: FirebaseBootstrapState.missingConfig,
    );
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return const FirebaseBootstrapResult(
      state: FirebaseBootstrapState.initialized,
    );
  } on Object catch (error) {
    return FirebaseBootstrapResult(
      state: FirebaseBootstrapState.failed,
      error: error,
    );
  }
}
