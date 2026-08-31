import 'package:cloud_firestore/cloud_firestore.dart';

import 'child.dart';

/// Firestore access for the `children` catalog. See CONTEXT.md "Criança" /
/// "Gestão de crianças".
class ChildRepository {
  ChildRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _children =>
      _firestore.collection('children');

  Future<String> createChild({
    required String name,
    required String createdBy,
  }) async {
    final now = FieldValue.serverTimestamp();
    final docRef = await _children.add({
      'name': name,
      'active': true,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });
    return docRef.id;
  }

  /// Updates `name` and/or `active`. Pass only the fields that changed;
  /// `updatedBy`/`updatedAt` are always stamped. Never hard-deletes (see
  /// CONTEXT.md "Inativação de criança").
  Future<void> updateChild({
    required String childId,
    required String updatedBy,
    String? name,
    bool? active,
  }) async {
    final fields = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
    if (name != null) {
      fields['name'] = name;
    }
    if (active != null) {
      fields['active'] = active;
    }
    await _children.doc(childId).update(fields);
  }

  /// Active children, sorted by name. Sorted client-side to avoid requiring
  /// a composite index for `active == true` + `orderBy(name)` (indexes are
  /// out of scope for this ticket).
  Future<List<Child>> listActiveChildren() async {
    final snapshot = await _children.where('active', isEqualTo: true).get();
    final children = snapshot.docs
        .map((doc) => Child.fromFirestore(doc.id, doc.data()))
        .toList();
    children.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return children;
  }

  /// Live catalog for the Crianças screen (see CONTEXT.md "Gestão de
  /// crianças"): all children by default so gestão/admin can reactivate,
  /// or only active ones when [activeOnly] is true (cuidador). Sorted
  /// client-side to avoid a composite index.
  Stream<List<Child>> watchChildren({bool activeOnly = false}) {
    final query =
        activeOnly ? _children.where('active', isEqualTo: true) : _children;
    return query.snapshots().map((snapshot) {
      final children = snapshot.docs
          .map((doc) => Child.fromFirestore(doc.id, doc.data()))
          .toList();
      children.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return children;
    });
  }
}
