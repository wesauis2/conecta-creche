import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../fcm/notification_dispatch_service.dart';
import 'mural_post.dart';

/// Contrato do mural (timeline por efetividade). Ver CONTEXT.md "Mural".
abstract class MuralPostsRepository {
  Future<String> createPost({
    required String title,
    required String body,
    required MuralPostKind kind,
    required String createdBy,
    DateTime? releasedAt,
    DateTime? effectiveAt,
    bool requiresNotification = false,
    String? location,
    String? scheduleText,
  });

  Future<void> updatePost({
    required String postId,
    required String updatedBy,
    String? title,
    String? body,
    MuralPostKind? kind,
    DateTime? releasedAt,
    DateTime? effectiveAt,
    bool? requiresNotification,
    String? location,
    String? scheduleText,
    bool clearLocation = false,
    bool clearScheduleText = false,
  });

  Stream<List<MuralPost>> watchVisiblePosts({DateTime? asOf});

  Stream<List<MuralPost>> watchPosts({
    bool includeUnreleased = false,
    DateTime? asOf,
  });

  Future<List<MuralPost>> listVisiblePosts({
    DateTime? asOf,
    int pageSize = 20,
    DateTime? startAfterEffectiveAt,
    String? startAfterId,
  });
}

/// Acesso Firestore a `mural_posts`. Ver docs/requisitos/mural.md.
class MuralRepository implements MuralPostsRepository {
  MuralRepository({
    FirebaseFirestore? firestore,
    NotificationDispatchService? notificationDispatch,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationDispatch = notificationDispatch;

  final FirebaseFirestore _firestore;
  final NotificationDispatchService? _notificationDispatch;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('mural_posts');

  /// Cria publicação. Se [effectiveAt] for omitido, copia [releasedAt]
  /// (ou "agora" quando ambos omitidos — publicação imediata).
  /// Com [requiresNotification] e efetivo agora: grava feed + tenta FCM.
  @override
  Future<String> createPost({
    required String title,
    required String body,
    required MuralPostKind kind,
    required String createdBy,
    DateTime? releasedAt,
    DateTime? effectiveAt,
    bool requiresNotification = false,
    String? location,
    String? scheduleText,
  }) async {
    final now = DateTime.now().toUtc();
    final released = releasedAt ?? now;
    final effective = effectiveAt ?? released;
    final serverNow = FieldValue.serverTimestamp();

    final payload = <String, dynamic>{
      'title': title,
      'body': body,
      'kind': kind.firestoreValue,
      'createdAt': serverNow,
      'updatedAt': serverNow,
      'createdBy': createdBy,
      'updatedBy': createdBy,
      'releasedAt': Timestamp.fromDate(released),
      'effectiveAt': Timestamp.fromDate(effective),
      'requiresNotification': requiresNotification,
    };
    if (location != null && location.trim().isNotEmpty) {
      payload['location'] = location.trim();
    }
    if (scheduleText != null && scheduleText.trim().isNotEmpty) {
      payload['scheduleText'] = scheduleText.trim();
    }

    final docRef = await _posts.add(payload);

    final dispatch = _notificationDispatch;
    if (dispatch != null && requiresNotification) {
      try {
        await dispatch.dispatchMuralPost(
          postId: docRef.id,
          title: title,
          body: body,
          effectiveAt: effective,
          requiresNotification: true,
          asOf: now,
        );
      } on Object catch (error) {
        debugPrint('Mural: disparo de notificação falhou: $error');
      }
    }

    return docRef.id;
  }

  /// Atualização parcial; sempre carimba `updatedAt`/`updatedBy`.
  @override
  Future<void> updatePost({
    required String postId,
    required String updatedBy,
    String? title,
    String? body,
    MuralPostKind? kind,
    DateTime? releasedAt,
    DateTime? effectiveAt,
    bool? requiresNotification,
    String? location,
    String? scheduleText,
    bool clearLocation = false,
    bool clearScheduleText = false,
  }) async {
    final fields = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
    if (title != null) fields['title'] = title;
    if (body != null) fields['body'] = body;
    if (kind != null) fields['kind'] = kind.firestoreValue;
    if (releasedAt != null) {
      fields['releasedAt'] = Timestamp.fromDate(releasedAt);
    }
    if (effectiveAt != null) {
      fields['effectiveAt'] = Timestamp.fromDate(effectiveAt);
    }
    if (requiresNotification != null) {
      fields['requiresNotification'] = requiresNotification;
    }
    if (clearLocation) {
      fields['location'] = FieldValue.delete();
    } else if (location != null) {
      fields['location'] = location;
    }
    if (clearScheduleText) {
      fields['scheduleText'] = FieldValue.delete();
    } else if (scheduleText != null) {
      fields['scheduleText'] = scheduleText;
    }
    await _posts.doc(postId).update(fields);
  }

  /// Timeline ao vivo: só itens com `releasedAt <= asOf`, ordenados por
  /// `effectiveAt` desc (client-side para evitar índice composto).
  @override
  Stream<List<MuralPost>> watchVisiblePosts({DateTime? asOf}) {
    return watchPosts(includeUnreleased: false, asOf: asOf);
  }

  /// Feed com opção de incluir agendados (gestão+). Ordenação por
  /// `effectiveAt` desc.
  @override
  Stream<List<MuralPost>> watchPosts({
    bool includeUnreleased = false,
    DateTime? asOf,
  }) {
    return _posts.snapshots().map((snapshot) {
      final now = asOf ?? DateTime.now();
      final posts = snapshot.docs
          .map((doc) => MuralPost.fromFirestore(doc.id, doc.data()))
          .where((post) => includeUnreleased || post.isReleased(asOf: now))
          .toList();
      sortMuralPostsByEffectiveAtDesc(posts);
      return posts;
    });
  }

  /// Página da timeline visível (scroll infinito). Ordenação estável por
  /// `effectiveAt` desc, desempate por id desc.
  @override
  Future<List<MuralPost>> listVisiblePosts({
    DateTime? asOf,
    int pageSize = 20,
    DateTime? startAfterEffectiveAt,
    String? startAfterId,
  }) async {
    final now = asOf ?? DateTime.now();
    final snapshot = await _posts.get();
    final posts = snapshot.docs
        .map((doc) => MuralPost.fromFirestore(doc.id, doc.data()))
        .where((post) => post.isReleased(asOf: now))
        .toList();
    sortMuralPostsByEffectiveAtDesc(posts);

    Iterable<MuralPost> page = posts;
    if (startAfterEffectiveAt != null && startAfterId != null) {
      page = posts.where((post) {
        final cmp = post.effectiveAt.compareTo(startAfterEffectiveAt);
        if (cmp != 0) return cmp < 0;
        return post.id.compareTo(startAfterId) < 0;
      });
    }
    return page.take(pageSize).toList(growable: false);
  }
}

void sortMuralPostsByEffectiveAtDesc(List<MuralPost> posts) {
  posts.sort((a, b) {
    final byEffective = b.effectiveAt.compareTo(a.effectiveAt);
    if (byEffective != 0) return byEffective;
    return b.id.compareTo(a.id);
  });
}

/// Repositório em memória para previews/dev sem Firebase.
class MemoryMuralRepository implements MuralPostsRepository {
  MemoryMuralRepository() : _controller = StreamController.broadcast();

  final List<MuralPost> _posts = <MuralPost>[];
  final StreamController<void> _controller;
  var _seq = 0;

  void dispose() {
    _controller.close();
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  List<MuralPost> _filtered({
    required bool includeUnreleased,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final posts = _posts
        .where((post) => includeUnreleased || post.isReleased(asOf: now))
        .toList();
    sortMuralPostsByEffectiveAtDesc(posts);
    return posts;
  }

  @override
  Future<String> createPost({
    required String title,
    required String body,
    required MuralPostKind kind,
    required String createdBy,
    DateTime? releasedAt,
    DateTime? effectiveAt,
    bool requiresNotification = false,
    String? location,
    String? scheduleText,
  }) async {
    final now = DateTime.now();
    final released = releasedAt ?? now;
    final effective = effectiveAt ?? released;
    final id = 'mem_${_seq++}';
    _posts.add(
      MuralPost(
        id: id,
        title: title,
        body: body,
        kind: kind,
        releasedAt: released,
        effectiveAt: effective,
        requiresNotification: requiresNotification,
        createdAt: now,
        updatedAt: now,
        createdBy: createdBy,
        updatedBy: createdBy,
        location: location,
        scheduleText: scheduleText,
      ),
    );
    _notify();
    return id;
  }

  @override
  Future<void> updatePost({
    required String postId,
    required String updatedBy,
    String? title,
    String? body,
    MuralPostKind? kind,
    DateTime? releasedAt,
    DateTime? effectiveAt,
    bool? requiresNotification,
    String? location,
    String? scheduleText,
    bool clearLocation = false,
    bool clearScheduleText = false,
  }) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final current = _posts[index];
    _posts[index] = MuralPost(
      id: current.id,
      title: title ?? current.title,
      body: body ?? current.body,
      kind: kind ?? current.kind,
      releasedAt: releasedAt ?? current.releasedAt,
      effectiveAt: effectiveAt ?? current.effectiveAt,
      requiresNotification:
          requiresNotification ?? current.requiresNotification,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
      createdBy: current.createdBy,
      updatedBy: updatedBy,
      location: clearLocation ? null : (location ?? current.location),
      scheduleText:
          clearScheduleText ? null : (scheduleText ?? current.scheduleText),
    );
    _notify();
  }

  @override
  Stream<List<MuralPost>> watchVisiblePosts({DateTime? asOf}) {
    return watchPosts(includeUnreleased: false, asOf: asOf);
  }

  @override
  Stream<List<MuralPost>> watchPosts({
    bool includeUnreleased = false,
    DateTime? asOf,
  }) async* {
    yield _filtered(includeUnreleased: includeUnreleased, asOf: asOf);
    await for (final _ in _controller.stream) {
      yield _filtered(includeUnreleased: includeUnreleased, asOf: asOf);
    }
  }

  @override
  Future<List<MuralPost>> listVisiblePosts({
    DateTime? asOf,
    int pageSize = 20,
    DateTime? startAfterEffectiveAt,
    String? startAfterId,
  }) async {
    final posts = _filtered(includeUnreleased: false, asOf: asOf);
    Iterable<MuralPost> page = posts;
    if (startAfterEffectiveAt != null && startAfterId != null) {
      page = posts.where((post) {
        final cmp = post.effectiveAt.compareTo(startAfterEffectiveAt);
        if (cmp != 0) return cmp < 0;
        return post.id.compareTo(startAfterId) < 0;
      });
    }
    return page.take(pageSize).toList(growable: false);
  }
}
