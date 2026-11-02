import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Tipo de publicação do mural. Ver docs/requisitos/mural.md.
enum MuralPostKind {
  comunicado,
  evento,
  recado;

  String get firestoreValue => name;

  static MuralPostKind fromFirestore(String? value) {
    return MuralPostKind.values.firstWhere(
      (k) => k.name == value,
      orElse: () => MuralPostKind.comunicado,
    );
  }

  String get label => switch (this) {
        MuralPostKind.comunicado => 'Comunicado',
        MuralPostKind.evento => 'Evento',
        MuralPostKind.recado => 'Recado',
      };

  IconData get icon => switch (this) {
        MuralPostKind.comunicado => Icons.campaign_outlined,
        MuralPostKind.evento => Icons.event_outlined,
        MuralPostKind.recado => Icons.sticky_note_2_outlined,
      };
}

/// Publicação em `mural_posts/{id}`.
///
/// Liberação (`releasedAt`) controla visibilidade; efetividade (`effectiveAt`)
/// ancora a ordenação da timeline (default = `releasedAt`). Ver CONTEXT.md
/// "Mural" / "Liberação / efetividade".
class MuralPost {
  const MuralPost({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.releasedAt,
    required this.effectiveAt,
    this.requiresNotification = false,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.location,
    this.scheduleText,
  });

  final String id;
  final String title;
  final String body;
  final MuralPostKind kind;
  final DateTime releasedAt;
  final DateTime effectiveAt;

  /// Se true e `effectiveAt <= now` no create, emite notificação/FCM.
  /// Ver docs/requisitos/notificacoes-push.md.
  final bool requiresNotification;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  /// Campos opcionais de evento.
  final String? location;
  final String? scheduleText;

  bool isReleased({DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    return !releasedAt.isAfter(now);
  }

  factory MuralPost.fromFirestore(String id, Map<String, dynamic> data) {
    final released = _readDate(data['releasedAt']) ??
        _readDate(data['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final effective = _readDate(data['effectiveAt']) ?? released;

    return MuralPost(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      kind: MuralPostKind.fromFirestore(data['kind'] as String?),
      releasedAt: released,
      effectiveAt: effective,
      requiresNotification: data['requiresNotification'] as bool? ?? false,
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
      location: data['location'] as String?,
      scheduleText: data['scheduleText'] as String?,
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
