import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../fcm/notification_dispatch_service.dart';
import '../forms/form_question.dart';
import 'parecer.dart';
import 'presence_answer.dart';
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
  PresenceRepository({
    FirebaseFirestore? firestore,
    NotificationDispatchService? notificationDispatch,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationDispatch = notificationDispatch;

  final FirebaseFirestore _firestore;
  final NotificationDispatchService? _notificationDispatch;

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

  /// Registers a saída: grava answers com `recordedPhase=saida` (se houver),
  /// depois fecha o registro (`departedAt`, `isOpen: false`).
  ///
  /// [parecer] permanece como compat legado; preferir [answers] do formulário
  /// configurável. Recusa se o registro já estiver fechado.
  /// Never changes `childId`/`dayKey`/`arrivedAt` (admin-only elsewhere).
  Future<void> registerDeparture({
    required String recordId,
    required DateTime departedAt,
    required String updatedBy,
    Parecer? parecer,
    List<DepartureAnswerDraft>? answers,
  }) async {
    final recordSnap = await _records.doc(recordId).get();
    final data = recordSnap.data();
    if (data == null) {
      throw StateError('presence record $recordId not found');
    }
    if (data['isOpen'] != true) {
      throw PresenceRecordClosedException(recordId: recordId);
    }

    final childId = data['childId'] as String? ?? '';

    // Answers must be written while the record is still open.
    for (final draft in answers ?? const <DepartureAnswerDraft>[]) {
      final docRef = await _answers(recordId).add(
        PresenceAnswer.toCreateMap(
          question: draft.question,
          value: draft.value,
          recordedPhase: RecordedPhase.saida,
          createdBy: updatedBy,
          recordedAt: departedAt,
        ),
      );
      if (draft.question.flags.incident) {
        await _dispatchIncidentQuietly(
          childId: childId,
          answerId: docRef.id,
          question: draft.question,
          value: draft.value,
          recordedAt: departedAt,
        );
      }
    }

    await _records.doc(recordId).update(
      PresenceRecord.toDepartureMap(
        departedAt: departedAt,
        parecer: parecer,
        updatedBy: updatedBy,
      ),
    );
  }

  /// Registros de uma criança, ordenados por `arrivedAt` (mais recente
  /// primeiro). Usado no feed misto do mural do responsável.
  Future<List<PresenceRecord>> listByChildId({required String childId}) async {
    final snapshot =
        await _records.where('childId', isEqualTo: childId).get();
    final records = snapshot.docs
        .map((doc) => PresenceRecord.fromFirestore(doc.id, doc.data()))
        .toList();
    records.sort((a, b) => b.arrivedAt.compareTo(a.arrivedAt));
    return records;
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

  CollectionReference<Map<String, dynamic>> _answers(String recordId) =>
      _records.doc(recordId).collection('answers');

  /// Grava uma answer no registro aberto (ocorrência/incidente durante o dia
  /// ou resposta na saída). Snapshot da pergunta + flags no momento. Ver
  /// CONTEXT.md "Resposta (answer)" / "Incidente".
  Future<String> registerAnswer({
    required String recordId,
    required FormQuestion question,
    required Object? value,
    required RecordedPhase recordedPhase,
    required String createdBy,
    DateTime? recordedAt,
  }) async {
    final recordSnap = await _records.doc(recordId).get();
    final data = recordSnap.data();
    if (data == null) {
      throw StateError('presence record $recordId not found');
    }
    if (data['isOpen'] != true) {
      throw PresenceRecordClosedException(recordId: recordId);
    }

    final instant = recordedAt ?? PresenceClock.now();
    final docRef = await _answers(recordId).add(
      PresenceAnswer.toCreateMap(
        question: question,
        value: value,
        recordedPhase: recordedPhase,
        createdBy: createdBy,
        recordedAt: instant,
      ),
    );

    if (question.flags.incident) {
      await _dispatchIncidentQuietly(
        childId: data['childId'] as String? ?? '',
        answerId: docRef.id,
        question: question,
        value: value,
        recordedAt: instant,
      );
    }

    return docRef.id;
  }

  Future<void> _dispatchIncidentQuietly({
    required String childId,
    required String answerId,
    required FormQuestion question,
    required Object? value,
    required DateTime recordedAt,
  }) async {
    final dispatch = _notificationDispatch;
    if (dispatch == null || childId.isEmpty) return;

    final snapshot = QuestionSnapshot.fromQuestion(question);
    final answer = PresenceAnswer(
      id: answerId,
      questionSnapshot: snapshot,
      value: value,
      flagsSnapshot: question.flags,
      recordedPhase: RecordedPhase.duranteDia,
      recordedAt: recordedAt,
    );
    final title = 'Incidente · ${question.prompt}';
    final body = answer.displayValue.isEmpty
        ? 'Registro de incidente na creche.'
        : answer.displayValue;

    try {
      await dispatch.dispatchIncident(
        childId: childId,
        sourceId: answerId,
        title: title,
        body: body,
        emittedAt: recordedAt.toUtc(),
      );
    } on Object catch (error) {
      debugPrint('Presença: disparo de incidente falhou: $error');
    }
  }

  /// Edita o `value` de uma answer dentro da janela de 24h (`createdAt`).
  /// Atualiza `updatedBy`/`updatedAt`. [now] é injetável para testes.
  Future<void> updateAnswer({
    required String recordId,
    required String answerId,
    required Object? value,
    required String updatedBy,
    DateTime? now,
  }) async {
    final docRef = _answers(recordId).doc(answerId);
    final snap = await docRef.get();
    final data = snap.data();
    if (data == null) {
      throw StateError('answer $answerId not found on record $recordId');
    }

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) {
      throw StateError('answer $answerId missing createdAt');
    }

    AnswerEditGuard.ensureCanEdit(
      createdAt: createdAt,
      now: now ?? PresenceClock.now(),
    );

    await docRef.update({
      'value': value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  /// Answers do registro, ordenadas por `recordedAt` (client-side).
  Future<List<PresenceAnswer>> listAnswers({required String recordId}) async {
    final snapshot = await _answers(recordId).get();
    final answers = snapshot.docs
        .map((doc) => PresenceAnswer.fromFirestore(doc.id, doc.data()))
        .toList();
    answers.sort((a, b) {
      final aAt = a.recordedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.recordedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aAt.compareTo(bAt);
    });
    return answers;
  }

  /// Live answers do registro, ordenadas por `recordedAt`.
  Stream<List<PresenceAnswer>> watchAnswers({required String recordId}) {
    return _answers(recordId).snapshots().map((snapshot) {
      final answers = snapshot.docs
          .map((doc) => PresenceAnswer.fromFirestore(doc.id, doc.data()))
          .toList();
      answers.sort((a, b) {
        final aAt =
            a.recordedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt =
            b.recordedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aAt.compareTo(bAt);
      });
      return answers;
    });
  }

  /// Agrega answers com `flagsSnapshot.incident` entre registros.
  /// Filtros opcionais [dayKey] e [childId] restringem os registros-pai;
  /// reutiliza [listAnswers]. Ordenado do mais recente ao mais antigo.
  Future<List<PresenceIncident>> listIncidents({
    String? dayKey,
    String? childId,
  }) async {
    Query<Map<String, dynamic>> query = _records;
    if (dayKey != null) {
      query = query.where('dayKey', isEqualTo: dayKey);
    }
    if (childId != null) {
      query = query.where('childId', isEqualTo: childId);
    }

    final snapshot = await query.get();
    final incidents = <PresenceIncident>[];
    for (final doc in snapshot.docs) {
      final record = PresenceRecord.fromFirestore(doc.id, doc.data());
      final answers = await listAnswers(recordId: record.id);
      for (final answer in answers) {
        if (!answer.isIncident) continue;
        incidents.add(
          PresenceIncident(
            answer: answer,
            recordId: record.id,
            childId: record.childId,
            dayKey: record.dayKey,
          ),
        );
      }
    }

    incidents.sort((a, b) {
      final aAt = a.answer.recordedAt ??
          a.answer.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = b.answer.recordedAt ??
          b.answer.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return incidents;
  }
}
