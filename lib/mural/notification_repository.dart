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

  /// Sentinel em `userId` para broadcast (queryável; `null` quebra no fake
  /// e em list rules). Espelhado em firestore.rules `canReadNotification`.
  static const broadcastUserId = '__broadcast__';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  /// Grava o registro. Não dispara push.
  ///
  /// Sem destinatário: persiste `userId: __broadcast__` (queryável e
  /// legível por qualquer signed-in nas rules).
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
      'userId': (userId == null || userId.isEmpty) ? broadcastUserId : userId,
    };
    if (emitted != null) {
      payload['emittedAt'] = Timestamp.fromDate(emitted);
    }
    if (scheduledAt != null) {
      payload['scheduledAt'] = Timestamp.fromDate(scheduledAt);
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

  /// Notificações do destinatário + broadcasts, ordenadas por data análoga a
  /// `effectiveAt` (desc). Inclui só as já emitidas ou com
  /// `scheduledAt <= asOf`.
  ///
  /// Duas queries (próprias + `__broadcast__`) — list-all falha nas rules se
  /// existir doc de outro `userId`.
  @override
  Future<List<AppNotification>> listForUser(
    String uid, {
    DateTime? asOf,
  }) async {
    final now = asOf ?? DateTime.now();
    final own = await _notifications.where('userId', isEqualTo: uid).get();
    final broadcast = await _notifications
        .where('userId', isEqualTo: broadcastUserId)
        .get();

    final byId = <String, AppNotification>{};
    for (final doc in [...own.docs, ...broadcast.docs]) {
      byId[doc.id] = AppNotification.fromFirestore(doc.id, doc.data());
    }

    final items = byId.values.where((n) {
      if (n.emittedAt != null) return !n.emittedAt!.isAfter(now);
      if (n.scheduledAt != null) return !n.scheduledAt!.isAfter(now);
      return false;
    }).toList();
    items.sort((a, b) {
      final byDate = b.effectiveAt.compareTo(a.effectiveAt);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
    return items;
  }
}
