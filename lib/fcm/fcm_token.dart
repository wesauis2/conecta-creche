import 'package:cloud_firestore/cloud_firestore.dart';

/// Plataforma do device que registrou o token FCM.
enum FcmPlatform {
  android,
  ios,
  other;

  String get firestoreValue => name;

  static FcmPlatform fromFirestore(String? value) {
    return switch (value) {
      'android' => FcmPlatform.android,
      'ios' => FcmPlatform.ios,
      _ => FcmPlatform.other,
    };
  }
}

/// Registro em `fcm_tokens/{id}` — token FCM do device ligado ao uid.
/// Ver docs/requisitos/notificacoes-push.md.
class FcmToken {
  const FcmToken({
    required this.id,
    required this.uid,
    required this.token,
    required this.platform,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String uid;
  final String token;
  final FcmPlatform platform;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Id estável por valor do token (upsert idempotente).
  static String docIdForToken(String token) => token;

  factory FcmToken.fromFirestore(String id, Map<String, dynamic> data) {
    return FcmToken(
      id: id,
      uid: data['uid'] as String? ?? '',
      token: data['token'] as String? ?? '',
      platform: FcmPlatform.fromFirestore(data['platform'] as String?),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreCreate({required DateTime now}) {
    return {
      'uid': uid,
      'token': token,
      'platform': platform.firestoreValue,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
