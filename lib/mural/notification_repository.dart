import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_notification.dart';

/// Persistência de `notifications` (feed). Envio FCM: ver
/// `lib/fcm/notification_dispatch_service.dart` e
/// docs/requisitos/notificacoes-push.md.
abstract class NotificationsRepository {
  Future<String> createNotification({
    required String title,
    required String body,
    DateTime? emittedAt,
    DateTime? scheduledAt,
    String? userId,
    NotificationSourceType? sourceType,
    String? sourceId,
  });

  Future<List<AppNotification>> listForUser(String uid, {DateTime? asOf});
}

class NotificationRepository implements NotificationsRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  /// Grava o registro. Não dispara push.
  @override
  Future<String> createNotification({
    required String title,
    required String body,
    DateTime? emittedAt,
    DateTime? scheduledAt,
    String? userId,
    NotificationSourceType? sourceType,
    String? sourceId,
  }) async {
    final now = DateTime.now().toUtc();
    final emitted = emittedAt ?? (scheduledAt == null ? now : null);
    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (emitted != null) {
      payload['emittedAt'] = Timestamp.fromDate(emitted);
    }
    if (scheduledAt != null) {
      payload['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    }
    if (userId != null) {
      payload['userId'] = userId;
    }
    if (sourceType != null) {
      payload['sourceType'] = sourceType.firestoreValue;
    }
    if (sourceId != null) {
      payload['sourceId'] = sourceId;
    }

    final docRef = await _notifications.add(payload);
    return docRef.id;
  }

  /// Notificações do destinatário + broadcasts (`userId` ausente), ordenadas
  /// por data análoga a `effectiveAt` (desc). Inclui só as já emitidas ou
  /// com `scheduledAt <= asOf`.
  @override
  Future<List<AppNotification>> listForUser(
    String uid, {
    DateTime? asOf,
  }) async {
    final now = asOf ?? DateTime.now();
    final snapshot = await _notifications.get();
    final items = snapshot.docs
        .map((doc) => AppNotification.fromFirestore(doc.id, doc.data()))
        .where((n) {
          final forUser = n.userId == null || n.userId == uid;
          if (!forUser) return false;
          if (n.emittedAt != null) return !n.emittedAt!.isAfter(now);
          if (n.scheduledAt != null) return !n.scheduledAt!.isAfter(now);
          return false;
        })
        .toList();
    items.sort((a, b) {
      final byDate = b.effectiveAt.compareTo(a.effectiveAt);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
    return items;
  }
}
