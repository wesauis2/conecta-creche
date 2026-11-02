import 'package:flutter/foundation.dart';

import '../mural/app_notification.dart';
import '../mural/notification_repository.dart';
import '../presence/child_repository.dart';
import 'fcm_sender.dart';
import 'fcm_token_repository.dart';

/// Resultado de um disparo (feed + tentativa FCM).
class NotificationDispatchResult {
  const NotificationDispatchResult({
    required this.notificationIds,
    required this.sendAttempts,
    required this.sendSuccesses,
  });

  final List<String> notificationIds;
  final int sendAttempts;
  final int sendSuccesses;

  bool get createdAny => notificationIds.isNotEmpty;
}

/// Cria registros em `notifications/` e tenta push via [FcmSender].
/// Ver docs/requisitos/notificacoes-push.md (RF0004).
class NotificationDispatchService {
  NotificationDispatchService({
    required NotificationsRepository notifications,
    required FcmTokensRepository tokens,
    required ChildRepository children,
    FcmSender? sender,
  })  : _notifications = notifications,
        _tokens = tokens,
        _children = children,
        _sender = sender ?? const NoOpFcmSender();

  final NotificationsRepository _notifications;
  final FcmTokensRepository _tokens;
  final ChildRepository _children;
  final FcmSender _sender;

  /// Incidente (`flags.incident`): um doc por responsável vinculado + FCM.
  Future<NotificationDispatchResult> dispatchIncident({
    required String childId,
    required String sourceId,
    required String title,
    required String body,
    DateTime? emittedAt,
    List<String>? responsibleUids,
  }) async {
    final uids = responsibleUids ??
        (await _children.getChild(childId))?.responsibleUids ??
        const <String>[];
    if (uids.isEmpty) {
      debugPrint(
        'FCM dispatch: incidente $sourceId sem responsáveis em $childId',
      );
      return const NotificationDispatchResult(
        notificationIds: [],
        sendAttempts: 0,
        sendSuccesses: 0,
      );
    }

    final emitted = emittedAt ?? DateTime.now().toUtc();
    final ids = <String>[];
    var attempts = 0;
    var successes = 0;

    for (final uid in uids.toSet()) {
      try {
        final id = await _notifications.createNotification(
          title: title,
          body: body,
          emittedAt: emitted,
          userId: uid,
          sourceType: NotificationSourceType.incident,
          sourceId: sourceId,
        );
        ids.add(id);

        final sent = await _sendToUid(
          uid: uid,
          title: title,
          body: body,
          data: {
            'sourceType': NotificationSourceType.incident.firestoreValue,
            'sourceId': sourceId,
            'notificationId': id,
            'title': title,
            'body': body,
          },
        );
        attempts += sent.attempts;
        successes += sent.successes;
      } on Object catch (error) {
        debugPrint('FCM dispatch: falha ao notificar $uid: $error');
      }
    }

    return NotificationDispatchResult(
      notificationIds: ids,
      sendAttempts: attempts,
      sendSuccesses: successes,
    );
  }

  /// Post do mural com flag “requer notificação” e `effectiveAt <= now`:
  /// broadcast no feed + tentativa FCM aos tokens conhecidos (ou [recipientUids]).
  Future<NotificationDispatchResult> dispatchMuralPost({
    required String postId,
    required String title,
    required String body,
    required DateTime effectiveAt,
    required bool requiresNotification,
    DateTime? asOf,
    List<String>? recipientUids,
  }) async {
    final now = asOf ?? DateTime.now().toUtc();
    if (!requiresNotification) {
      return const NotificationDispatchResult(
        notificationIds: [],
        sendAttempts: 0,
        sendSuccesses: 0,
      );
    }
    if (effectiveAt.isAfter(now)) {
      debugPrint(
        'FCM dispatch: mural $postId agendado (effectiveAt > now); '
        'só emite no create se efetivo agora.',
      );
      return const NotificationDispatchResult(
        notificationIds: [],
        sendAttempts: 0,
        sendSuccesses: 0,
      );
    }

    final ids = <String>[];
    var attempts = 0;
    var successes = 0;

    try {
      if (recipientUids == null || recipientUids.isEmpty) {
        final id = await _notifications.createNotification(
          title: title,
          body: body,
          emittedAt: effectiveAt.isAfter(now) ? now : effectiveAt,
          sourceType: NotificationSourceType.muralPost,
          sourceId: postId,
        );
        ids.add(id);

        final tokens = await _tokens.listAll();
        for (final token in tokens) {
          attempts++;
          final ok = await _sender.sendToToken(
            token: token.token,
            title: title,
            body: body,
            data: {
              'sourceType': NotificationSourceType.muralPost.firestoreValue,
              'sourceId': postId,
              'notificationId': id,
              'title': title,
              'body': body,
            },
          );
          if (ok) successes++;
        }
      } else {
        final emitted = effectiveAt.isAfter(now) ? now : effectiveAt;
        for (final uid in recipientUids.toSet()) {
          final id = await _notifications.createNotification(
            title: title,
            body: body,
            emittedAt: emitted,
            userId: uid,
            sourceType: NotificationSourceType.muralPost,
            sourceId: postId,
          );
          ids.add(id);
          final sent = await _sendToUid(
            uid: uid,
            title: title,
            body: body,
            data: {
              'sourceType': NotificationSourceType.muralPost.firestoreValue,
              'sourceId': postId,
              'notificationId': id,
              'title': title,
              'body': body,
            },
          );
          attempts += sent.attempts;
          successes += sent.successes;
        }
      }
    } on Object catch (error) {
      debugPrint('FCM dispatch: falha no mural $postId: $error');
    }

    return NotificationDispatchResult(
      notificationIds: ids,
      sendAttempts: attempts,
      sendSuccesses: successes,
    );
  }

  Future<({int attempts, int successes})> _sendToUid({
    required String uid,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    final tokens = await _tokens.listForUid(uid);
    var attempts = 0;
    var successes = 0;
    for (final token in tokens) {
      if (token.token.isEmpty) continue;
      attempts++;
      final ok = await _sender.sendToToken(
        token: token.token,
        title: title,
        body: body,
        data: data,
      );
      if (ok) successes++;
    }
    return (attempts: attempts, successes: successes);
  }
}
