import 'package:cloud_firestore/cloud_firestore.dart';

import 'fcm_token.dart';

/// Persistência de `fcm_tokens` (dono = uid). Compatível com firestore.rules.
abstract class FcmTokensRepository {
  /// Cria ou atualiza o doc do token (id = valor do token).
  Future<void> upsertToken({
    required String uid,
    required String token,
    required FcmPlatform platform,
    DateTime? now,
  });

  /// Remove o doc deste token (ex.: logout do device).
  Future<void> deleteToken(String token);

  /// Lista tokens do uid (útil em testes / limpeza).
  Future<List<FcmToken>> listForUid(String uid);
}

class FcmTokenRepository implements FcmTokensRepository {
  FcmTokenRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tokens =>
      _firestore.collection('fcm_tokens');

  @override
  Future<void> upsertToken({
    required String uid,
    required String token,
    required FcmPlatform platform,
    DateTime? now,
  }) async {
    if (token.isEmpty) return;

    final id = FcmToken.docIdForToken(token);
    final docRef = _tokens.doc(id);
    final existing = await docRef.get();
    final stamp = now ?? DateTime.now().toUtc();

    if (!existing.exists) {
      await docRef.set({
        'uid': uid,
        'token': token,
        'platform': platform.firestoreValue,
        'createdAt': Timestamp.fromDate(stamp),
        'updatedAt': Timestamp.fromDate(stamp),
      });
      return;
    }

    await docRef.update({
      'uid': uid,
      'token': token,
      'platform': platform.firestoreValue,
      'updatedAt': Timestamp.fromDate(stamp),
    });
  }

  @override
  Future<void> deleteToken(String token) async {
    if (token.isEmpty) return;
    await _tokens.doc(FcmToken.docIdForToken(token)).delete();
  }

  @override
  Future<List<FcmToken>> listForUid(String uid) async {
    final snapshot = await _tokens.where('uid', isEqualTo: uid).get();
    return snapshot.docs
        .map((doc) => FcmToken.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}
