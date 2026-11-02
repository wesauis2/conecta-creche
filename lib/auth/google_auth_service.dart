import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    this.serverClientId,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Web OAuth client ID (`client_type: 3` in google-services.json).
  /// Pass explicitly when the Gradle default string is unavailable.
  final String? serverClientId;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> ensureGoogleSignInInitialized() async {
    final fromEnv = const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    final resolved = serverClientId ?? (fromEnv.isEmpty ? null : fromEnv);

    await _googleSignIn.initialize(serverClientId: resolved);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!_googleSignIn.supportsAuthenticate()) {
      throw UnsupportedError(
        'Google Sign-In interativo não suportado nesta plataforma.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google Sign-In não retornou idToken.');
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw StateError(
          'Google Sign-In sem serverClientId. No Firebase: ative o provedor '
          'Google, adicione um app Web (ou confira o ID do cliente Web), '
          'cadastre o SHA-1 do keystore no app Android e baixe de novo o '
          'google-services.json. Ver docs/credentials.md.',
        );
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
