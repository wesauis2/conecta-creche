import 'package:cloud_firestore/cloud_firestore.dart';

/// Canal de acesso ao visualizar um comunicado. Ver
/// docs/requisitos/mural-leitura.md (RF0016).
enum MuralReadChannel {
  mural,
  notification;

  String get firestoreValue => switch (this) {
        MuralReadChannel.mural => 'mural',
        MuralReadChannel.notification => 'notification',
      };

  static MuralReadChannel fromFirestore(String? value) {
    return switch (value) {
      'notification' => MuralReadChannel.notification,
      _ => MuralReadChannel.mural,
    };
  }
}

/// Registro em `mural_reads/{id}` — leitura idempotente por
/// (`postId`, `uid`, `channel`).
class MuralRead {
  const MuralRead({
    required this.id,
    required this.postId,
    required this.uid,
    required this.channel,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.notificationId,
  });

  final String id;
  final String postId;
  final String uid;
  final MuralReadChannel channel;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final String? notificationId;

  /// Id estável para create-or-update idempotente.
  static String docId({
    required String postId,
    required String uid,
    required MuralReadChannel channel,
  }) =>
      '${postId}__${uid}__${channel.firestoreValue}';

  factory MuralRead.fromFirestore(String id, Map<String, dynamic> data) {
    return MuralRead(
      id: id,
      postId: data['postId'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      channel: MuralReadChannel.fromFirestore(data['channel'] as String?),
      firstSeenAt: _readDate(data['firstSeenAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastSeenAt: _readDate(data['lastSeenAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      notificationId: data['notificationId'] as String?,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
