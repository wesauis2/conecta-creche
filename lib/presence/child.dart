import 'package:cloud_firestore/cloud_firestore.dart';

/// A criança catalogued in `children/{id}`, identified only by name.
/// See CONTEXT.md "Criança".
class Child {
  const Child({
    required this.id,
    required this.name,
    required this.active,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String id;
  final String name;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  factory Child.fromFirestore(String id, Map<String, dynamic> data) {
    return Child(
      id: id,
      name: data['name'] as String,
      active: data['active'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
    );
  }
}
