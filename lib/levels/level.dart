import 'package:cloud_firestore/cloud_firestore.dart';

/// Nível institucional em `levels/{id}` (agrupamento etário/pedagógico).
/// Ver CONTEXT.md "Nível" e docs/requisitos/niveis-turmas.md.
class Level {
  const Level({
    required this.id,
    required this.name,
    required this.sortIndex,
    required this.active,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String id;
  final String name;
  final int sortIndex;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  factory Level.fromFirestore(String id, Map<String, dynamic> data) {
    return Level(
      id: id,
      name: data['name'] as String? ?? '',
      sortIndex: (data['sortIndex'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
    );
  }
}
