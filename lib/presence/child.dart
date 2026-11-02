import 'package:cloud_firestore/cloud_firestore.dart';

/// A criança catalogued in `children/{id}`, identified only by name.
/// See CONTEXT.md "Criança" / "Vínculo criança↔responsável".
class Child {
  const Child({
    required this.id,
    required this.name,
    required this.active,
    this.responsibleUids = const [],
    this.levelId,
    this.classId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String id;
  final String name;
  final bool active;

  /// Uids de usuários `responsavel` vinculados. Índice queryável via
  /// `array-contains` (crianças do uid X).
  final List<String> responsibleUids;

  /// Nível atual (opcional). Ausência não bloqueia presença.
  final String? levelId;

  /// Turma atual (opcional). Ausência não bloqueia presença.
  final String? classId;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  factory Child.fromFirestore(String id, Map<String, dynamic> data) {
    final rawUids = data['responsibleUids'];
    final responsibleUids = rawUids is List
        ? rawUids.whereType<String>().toList(growable: false)
        : const <String>[];

    return Child(
      id: id,
      name: data['name'] as String,
      active: data['active'] as bool? ?? true,
      responsibleUids: responsibleUids,
      levelId: data['levelId'] as String?,
      classId: data['classId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
    );
  }
}
