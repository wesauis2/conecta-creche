import 'package:cloud_firestore/cloud_firestore.dart';

/// Turma do ano letivo em `classes/{id}`.
/// Sala é texto opcional na v1 (sem coleção `classrooms`).
/// Ver CONTEXT.md "Turma" e docs/requisitos/niveis-turmas.md.
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.year,
    required this.levelIds,
    this.room,
    required this.caregiverUids,
    required this.childIds,
    required this.active,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String id;
  final int year;
  final List<String> levelIds;

  /// Identificação livre da sala (texto opcional).
  final String? room;
  final List<String> caregiverUids;
  final List<String> childIds;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  String get displayLabel {
    final roomLabel = room?.trim();
    if (roomLabel != null && roomLabel.isNotEmpty) {
      return '$year · $roomLabel';
    }
    return 'Turma $year';
  }

  factory SchoolClass.fromFirestore(String id, Map<String, dynamic> data) {
    List<String> stringList(dynamic raw) {
      if (raw is List) {
        return raw.whereType<String>().toList(growable: false);
      }
      return const <String>[];
    }

    final roomRaw = data['room'] as String?;
    final roomTrimmed = roomRaw?.trim();

    return SchoolClass(
      id: id,
      year: (data['year'] as num?)?.toInt() ?? DateTime.now().year,
      levelIds: stringList(data['levelIds']),
      room: (roomTrimmed == null || roomTrimmed.isEmpty) ? null : roomTrimmed,
      caregiverUids: stringList(data['caregiverUids']),
      childIds: stringList(data['childIds']),
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
    );
  }
}
