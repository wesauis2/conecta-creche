import 'package:cloud_firestore/cloud_firestore.dart';

import 'level.dart';

/// Firestore access for `levels`. See CONTEXT.md "Nível".
class LevelRepository {
  LevelRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _levels =>
      _firestore.collection('levels');

  Future<String> createLevel({
    required String name,
    required String createdBy,
    int? sortIndex,
    bool active = true,
  }) async {
    final now = FieldValue.serverTimestamp();
    final resolvedSort = sortIndex ?? await _nextSortIndex();
    final docRef = await _levels.add({
      'name': name,
      'sortIndex': resolvedSort,
      'active': active,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });
    return docRef.id;
  }

  Future<int> _nextSortIndex() async {
    final snapshot = await _levels.get();
    var max = -1;
    for (final doc in snapshot.docs) {
      final value = (doc.data()['sortIndex'] as num?)?.toInt() ?? 0;
      if (value > max) {
        max = value;
      }
    }
    return max + 1;
  }

  /// Partial update; always stamps audit. Soft-deactivate via [active].
  Future<void> updateLevel({
    required String levelId,
    required String updatedBy,
    String? name,
    int? sortIndex,
    bool? active,
  }) async {
    final fields = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
    if (name != null) {
      fields['name'] = name;
    }
    if (sortIndex != null) {
      fields['sortIndex'] = sortIndex;
    }
    if (active != null) {
      fields['active'] = active;
    }
    await _levels.doc(levelId).update(fields);
  }

  /// Live list sorted by `sortIndex` (client-side; avoids composite index).
  Stream<List<Level>> watchLevels({bool activeOnly = false}) {
    final query =
        activeOnly ? _levels.where('active', isEqualTo: true) : _levels;
    return query.snapshots().map((snapshot) {
      final levels = snapshot.docs
          .map((doc) => Level.fromFirestore(doc.id, doc.data()))
          .toList();
      levels.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
      return levels;
    });
  }

  Future<List<Level>> listLevels({bool activeOnly = false}) async {
    final query =
        activeOnly ? _levels.where('active', isEqualTo: true) : _levels;
    final snapshot = await query.get();
    final levels = snapshot.docs
        .map((doc) => Level.fromFirestore(doc.id, doc.data()))
        .toList();
    levels.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return levels;
  }
}
