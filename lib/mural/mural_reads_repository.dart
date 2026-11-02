import 'package:cloud_firestore/cloud_firestore.dart';

import 'mural_read.dart';

/// Persistência de confirmações de leitura do mural (RF0016).
/// Ver docs/requisitos/mural-leitura.md.
abstract class MuralReadsRepository {
  /// Registra (ou atualiza `lastSeenAt`) a visualização do post.
  /// Idempotente por (`postId`, `uid`, `channel`).
  Future<void> recordRead({
    required String postId,
    required String uid,
    required MuralReadChannel channel,
    String? notificationId,
    DateTime? seenAt,
  });

  /// Contagem de leitores distintos (`uid`) do post.
  Future<int> countReaders(String postId);

  /// Stream da contagem de leitores distintos.
  Stream<int> watchReaderCount(String postId);
}

class MuralReadsRepositoryImpl implements MuralReadsRepository {
  MuralReadsRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reads =>
      _firestore.collection('mural_reads');

  @override
  Future<void> recordRead({
    required String postId,
    required String uid,
    required MuralReadChannel channel,
    String? notificationId,
    DateTime? seenAt,
  }) async {
    final now = seenAt ?? DateTime.now().toUtc();
    final id = MuralRead.docId(postId: postId, uid: uid, channel: channel);
    final docRef = _reads.doc(id);
    final existing = await docRef.get();

    if (!existing.exists) {
      final payload = <String, dynamic>{
        'postId': postId,
        'uid': uid,
        'channel': channel.firestoreValue,
        'firstSeenAt': Timestamp.fromDate(now),
        'lastSeenAt': Timestamp.fromDate(now),
      };
      if (notificationId != null && notificationId.isNotEmpty) {
        payload['notificationId'] = notificationId;
      }
      await docRef.set(payload);
      return;
    }

    final update = <String, dynamic>{
      'lastSeenAt': Timestamp.fromDate(now),
    };
    if (notificationId != null && notificationId.isNotEmpty) {
      update['notificationId'] = notificationId;
    }
    await docRef.update(update);
  }

  @override
  Future<int> countReaders(String postId) async {
    final snapshot =
        await _reads.where('postId', isEqualTo: postId).get();
    final uids = <String>{};
    for (final doc in snapshot.docs) {
      final uid = doc.data()['uid'] as String?;
      if (uid != null && uid.isNotEmpty) uids.add(uid);
    }
    return uids.length;
  }

  @override
  Stream<int> watchReaderCount(String postId) {
    return _reads.where('postId', isEqualTo: postId).snapshots().map((snap) {
      final uids = <String>{};
      for (final doc in snap.docs) {
        final uid = doc.data()['uid'] as String?;
        if (uid != null && uid.isNotEmpty) uids.add(uid);
      }
      return uids.length;
    });
  }
}
