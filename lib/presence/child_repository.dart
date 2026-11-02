import 'package:cloud_firestore/cloud_firestore.dart';

import 'child.dart';

/// Firestore access for the `children` catalog. See CONTEXT.md "Criança" /
/// "Gestão de crianças" / "Vínculo criança↔responsável".
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
      'responsibleUids': <String>[],
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

  /// Substitui o conjunto de responsáveis da criança. Não toca
  /// `presence_records` (remover vínculo não apaga histórico).
  Future<void> setChildResponsibles({
    required String childId,
    required List<String> responsibleUids,
    required String updatedBy,
  }) async {
    final unique = <String>{...responsibleUids}.toList(growable: false);
    await _children.doc(childId).update({
      'responsibleUids': unique,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  /// Crianças vinculadas ao uid (ativas e inativas), ordenadas por nome.
  /// Query `array-contains` em `responsibleUids`.
  Future<List<Child>> listChildrenForResponsible(String uid) async {
    final snapshot =
        await _children.where('responsibleUids', arrayContains: uid).get();
    final children = snapshot.docs
        .map((doc) => Child.fromFirestore(doc.id, doc.data()))
        .toList();
    children.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return children;
  }

  /// Sincroniza vínculos ativos do responsável: [activeChildIds] passa a
  /// incluir o uid; crianças ativas fora da lista perdem o vínculo.
  /// Vínculos com crianças **inativas** são preservados (histórico de
  /// leitura). Não apaga presença.
  Future<void> setResponsibleActiveChildren({
    required String uid,
    required Iterable<String> activeChildIds,
    required String updatedBy,
  }) async {
    final desiredActive = activeChildIds.toSet();
    final currentlyLinked = await listChildrenForResponsible(uid);
    final inactiveLinkedIds = currentlyLinked
        .where((child) => !child.active)
        .map((child) => child.id)
        .toSet();
    final desired = desiredActive.union(inactiveLinkedIds);
    final currentlyLinkedIds = currentlyLinked.map((c) => c.id).toSet();

    final toAdd = desired.difference(currentlyLinkedIds);
    final toRemove = currentlyLinkedIds.difference(desired);
    if (toAdd.isEmpty && toRemove.isEmpty) {
      return;
    }

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    for (final id in toAdd) {
      batch.update(_children.doc(id), {
        'responsibleUids': FieldValue.arrayUnion([uid]),
        'updatedAt': now,
        'updatedBy': updatedBy,
      });
    }
    for (final id in toRemove) {
      batch.update(_children.doc(id), {
        'responsibleUids': FieldValue.arrayRemove([uid]),
        'updatedAt': now,
        'updatedBy': updatedBy,
      });
    }
    await batch.commit();
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
