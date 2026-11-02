import 'package:cloud_firestore/cloud_firestore.dart';

import 'parecer.dart';
import 'presence_clock.dart';
import 'presence_open_guard.dart';
import 'presence_record.dart';

/// Firestore access for `presence_records`. See CONTEXT.md "Registro de
/// presença" / "Registro aberto" and
/// `.scratch/registro-presenca/research/dia-civil-firestore.md`.
///
/// Callers compute `dayKey`/instants via `PresenceClock` so this repository
/// stays free of timezone concerns; it only enforces the open-guard and
/// shapes the Firestore writes/reads.
class PresenceRepository {
  PresenceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection('presence_records');

  Query<Map<String, dynamic>> _openQueryFor(String childId, String dayKey) =>
      _records
          .where('childId', isEqualTo: childId)
          .where('dayKey', isEqualTo: dayKey)
          .where('isOpen', isEqualTo: true);

  /// Registers a chegada. Throws [OpenPresenceRecordException] if the child
  /// already has an open record for [dayKey].
  ///
  /// The Flutter Firestore client only supports transactional reads by
  /// document reference (not by query), so the open check runs inside the
  /// transaction callback as a regular query read immediately before the
  /// transactional write — this keeps the create atomic and the race
  /// window effectively nil for this product's staff-scale concurrency
  /// (see `.scratch/registro-presenca/research/dia-civil-firestore.md`).
  Future<String> registerArrival({
    required String childId,
    required String dayKey,
    required DateTime arrivedAt,
    required String createdBy,
  }) {
    return _firestore.runTransaction<String>((transaction) async {
      final openMatches = await _openQueryFor(childId, dayKey).limit(1).get();

      PresenceOpenGuard.ensureCanCreateArrival(
        childId: childId,
        dayKey: dayKey,
        hasOpenRecordForDay: openMatches.docs.isNotEmpty,
      );

      final docRef = _records.doc();
      transaction.set(
        docRef,
        PresenceRecord.toArrivalMap(
          childId: childId,
          dayKey: dayKey,
          arrivedAt: arrivedAt,
          createdBy: createdBy,
        ),
      );
      return docRef.id;
    });
  }

  /// Registers a saída with its parecer, closing the open record.
  /// Never changes `childId`/`dayKey`/`arrivedAt` (admin-only elsewhere).
  Future<void> registerDeparture({
    required String recordId,
    required DateTime departedAt,
    required Parecer parecer,
    required String updatedBy,
  }) async {
    await _records.doc(recordId).update(
      PresenceRecord.toDepartureMap(
        departedAt: departedAt,
        parecer: parecer,
        updatedBy: updatedBy,
      ),
    );
  }

  /// Records for a civil day, ordered by `arrivedAt`. Pass [isOpen] to
  /// restrict to open (Presentes) or closed (Saíram) records.
  Future<List<PresenceRecord>> listByDayKey({
    required String dayKey,
    bool? isOpen,
  }) async {
    Query<Map<String, dynamic>> query = _records.where(
      'dayKey',
      isEqualTo: dayKey,
    );
    if (isOpen != null) {
      query = query.where('isOpen', isEqualTo: isOpen);
    }

    final snapshot = await query.get();
    final records = snapshot.docs
        .map((doc) => PresenceRecord.fromFirestore(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
    return records;
  }

  /// Live records for a civil day, ordered by `arrivedAt`. Mirrors
  /// [listByDayKey] but as a stream, for screens that need to react to
  /// chegada/saída as they happen (e.g. the cuidador day view).
  Stream<List<PresenceRecord>> watchByDayKey({
    required String dayKey,
    bool? isOpen,
  }) {
    Query<Map<String, dynamic>> query = _records.where(
      'dayKey',
      isEqualTo: dayKey,
    );
    if (isOpen != null) {
      query = query.where('isOpen', isEqualTo: isOpen);
    }

    return query.snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => PresenceRecord.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
      return records;
    });
  }

  /// Updates only the `parecer` of an existing record (open or already
  /// closed), without touching `arrivedAt`/`departedAt`/`isOpen`. Used when
  /// the cuidador corrects a saída's parecer later in the same flow. See
  /// CONTEXT.md "Parecer".
  Future<void> updateParecer({
    required String recordId,
    required Parecer parecer,
    required String updatedBy,
  }) async {
    await _records.doc(recordId).update({
      'parecer': parecer.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  /// Admin-only correction of `arrivedAt`/`departedAt` on an existing
  /// record, recalculating `dayKey` (from the new `arrivedAt`, in São Paulo
  /// civil time) and `isOpen` (true when [departedAt] is `null`). Firestore
  /// rules reject this update for non-admin roles; callers should also gate
  /// the affordance on `UserRole.canAdminPresence`. See CONTEXT.md
  /// "Chegada" / "Saída".
  Future<void> adminUpdateTimestamps({
    required String recordId,
    required DateTime arrivedAt,
    DateTime? departedAt,
    required String updatedBy,
  }) async {
    if (departedAt != null && !departedAt.isAfter(arrivedAt)) {
      throw ArgumentError.value(
        departedAt,
        'departedAt',
        'must be after arrivedAt',
      );
    }

    await _records.doc(recordId).update({
      'dayKey': PresenceClock.dayKeyFor(arrivedAt),
      'arrivedAt': Timestamp.fromDate(arrivedAt),
      'departedAt': departedAt == null ? null : Timestamp.fromDate(departedAt),
      'isOpen': departedAt == null,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  /// Admin-only hard delete of a presence record (no soft delete/undo).
  /// Firestore rules reject this for non-admin roles; callers should also
  /// gate the affordance on `UserRole.canAdminPresence`.
  Future<void> adminDeleteRecord({required String recordId}) async {
    await _records.doc(recordId).delete();
  }

  /// Whether [childId] already has an open record on [dayKey]. Exposed for
  /// UI warnings (e.g. gestão's "aviso de abertos") without duplicating the
  /// query shape used by the open-guard.
  Future<bool> hasOpenRecord({
    required String childId,
    required String dayKey,
  }) async {
    final matches = await _openQueryFor(childId, dayKey).limit(1).get();
    return matches.docs.isNotEmpty;
  }
}
