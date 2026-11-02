import 'package:cloud_firestore/cloud_firestore.dart';

/// Origem do registro de notificação (espelho no mural). Ver
/// docs/requisitos/mural.md — envio FCM fica fora desta feature.
enum NotificationSourceType {
  muralPost,
  presence,
  incident,
  other;

  String get firestoreValue => switch (this) {
        NotificationSourceType.muralPost => 'mural_post',
        NotificationSourceType.presence => 'presence',
        NotificationSourceType.incident => 'incident',
        NotificationSourceType.other => 'other',
      };

  static NotificationSourceType fromFirestore(String? value) {
    return switch (value) {
      'mural_post' => NotificationSourceType.muralPost,
      'presence' => NotificationSourceType.presence,
      'incident' => NotificationSourceType.incident,
      _ => NotificationSourceType.other,
    };
  }
}

/// Registro em `notifications/{id}` (persistência apenas; sem FCM).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.emittedAt,
    this.scheduledAt,
    this.userId,
    this.sourceType,
    this.sourceId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? emittedAt;
  final DateTime? scheduledAt;
  final String? userId;
  final NotificationSourceType? sourceType;
  final String? sourceId;

  /// Âncora análoga a `effectiveAt` na timeline do mural.
  DateTime get effectiveAt =>
      emittedAt ??
      scheduledAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  factory AppNotification.fromFirestore(String id, Map<String, dynamic> data) {
    final rawUserId = data['userId'] as String?;
    return AppNotification(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      emittedAt: _readDate(data['emittedAt']),
      scheduledAt: _readDate(data['scheduledAt']),
      // Sentinel de broadcast → null no domínio (ver NotificationRepository).
      userId: (rawUserId == null ||
              rawUserId.isEmpty ||
              rawUserId == '__broadcast__')
          ? null
          : rawUserId,
      sourceType: data['sourceType'] == null
          ? null
          : NotificationSourceType.fromFirestore(data['sourceType'] as String?),
      sourceId: data['sourceId'] as String?,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
