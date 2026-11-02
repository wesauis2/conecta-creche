import 'package:cloud_firestore/cloud_firestore.dart';

import 'school_class.dart';

/// Firestore access for `classes` (turmas). See CONTEXT.md "Turma".
class ClassRepository {
  ClassRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _classes =>
      _firestore.collection('classes');

  CollectionReference<Map<String, dynamic>> get _children =>
      _firestore.collection('children');

  Future<String> createClass({
    required int year,
    required String createdBy,
    List<String> levelIds = const [],
    String? room,
    List<String> caregiverUids = const [],
    List<String> childIds = const [],
    bool active = true,
  }) async {
    final now = FieldValue.serverTimestamp();
    final uniqueLevels = <String>{...levelIds}.toList(growable: false);
    final uniqueCaregivers =
        <String>{...caregiverUids}.toList(growable: false);
    final uniqueChildren = <String>{...childIds}.toList(growable: false);
    final roomTrimmed = room?.trim();

    final docRef = _classes.doc();
    final batch = _firestore.batch();
    batch.set(docRef, {
      'year': year,
      'levelIds': uniqueLevels,
      'room': (roomTrimmed == null || roomTrimmed.isEmpty) ? null : roomTrimmed,
      'caregiverUids': uniqueCaregivers,
      'childIds': uniqueChildren,
      'active': active,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': createdBy,
      'updatedBy': createdBy,
    });

    for (final childId in uniqueChildren) {
      batch.update(_children.doc(childId), {
        'classId': docRef.id,
        'updatedAt': now,
        'updatedBy': createdBy,
      });
    }

    await batch.commit();
    return docRef.id;
  }

  /// Partial update; always stamps audit. Soft-deactivate via [active].
  /// When [childIds] is provided, syncs `children.classId` (adds/removes).
  Future<void> updateClass({
    required String classId,
    required String updatedBy,
    int? year,
    List<String>? levelIds,
    String? room,
    bool clearRoom = false,
    List<String>? caregiverUids,
    List<String>? childIds,
    bool? active,
  }) async {
    final now = FieldValue.serverTimestamp();
    final fields = <String, dynamic>{
      'updatedAt': now,
      'updatedBy': updatedBy,
    };
    if (year != null) {
      fields['year'] = year;
    }
    if (levelIds != null) {
      fields['levelIds'] = <String>{...levelIds}.toList(growable: false);
    }
    if (clearRoom) {
      fields['room'] = null;
    } else if (room != null) {
      final trimmed = room.trim();
      fields['room'] = trimmed.isEmpty ? null : trimmed;
    }
    if (caregiverUids != null) {
      fields['caregiverUids'] =
          <String>{...caregiverUids}.toList(growable: false);
    }
    if (active != null) {
      fields['active'] = active;
    }

    if (childIds == null) {
      await _classes.doc(classId).update(fields);
      return;
    }

    final desired = <String>{...childIds};
    final currentDoc = await _classes.doc(classId).get();
    final currentRaw = currentDoc.data()?['childIds'];
    final current = currentRaw is List
        ? currentRaw.whereType<String>().toSet()
        : <String>{};

    final toAdd = desired.difference(current);
    final toRemove = current.difference(desired);
    fields['childIds'] = desired.toList(growable: false);

    final batch = _firestore.batch();
    batch.update(_classes.doc(classId), fields);

    for (final childId in toAdd) {
      batch.update(_children.doc(childId), {
        'classId': classId,
        'updatedAt': now,
        'updatedBy': updatedBy,
      });
    }
    for (final childId in toRemove) {
      batch.update(_children.doc(childId), {
        'classId': null,
        'updatedAt': now,
        'updatedBy': updatedBy,
      });
    }
    await batch.commit();
  }

  /// Live list sorted by year desc then room (client-side).
  Stream<List<SchoolClass>> watchClasses({bool activeOnly = false}) {
    final query =
        activeOnly ? _classes.where('active', isEqualTo: true) : _classes;
    return query.snapshots().map((snapshot) {
      final classes = snapshot.docs
          .map((doc) => SchoolClass.fromFirestore(doc.id, doc.data()))
          .toList();
      _sortClasses(classes);
      return classes;
    });
  }

  Future<List<SchoolClass>> listClasses({bool activeOnly = false}) async {
    final query =
        activeOnly ? _classes.where('active', isEqualTo: true) : _classes;
    final snapshot = await query.get();
    final classes = snapshot.docs
        .map((doc) => SchoolClass.fromFirestore(doc.id, doc.data()))
        .toList();
    _sortClasses(classes);
    return classes;
  }

  void _sortClasses(List<SchoolClass> classes) {
    classes.sort((a, b) {
      final yearCmp = b.year.compareTo(a.year);
      if (yearCmp != 0) {
        return yearCmp;
      }
      return (a.room ?? '').toLowerCase().compareTo((b.room ?? '').toLowerCase());
    });
  }
}
