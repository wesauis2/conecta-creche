import 'package:cloud_firestore/cloud_firestore.dart';

import 'form_question.dart';

/// Firestore access for `form_questions`. See CONTEXT.md "Formulário configurável".
class FormQuestionRepository {
  FormQuestionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _questions =>
      _firestore.collection('form_questions');

  Future<String> createQuestion({
    required String prompt,
    required FormQuestionKind kind,
    required String createdBy,
    List<FormQuestionOption> options = const [],
    String? defaultOptionId,
    FormQuestionFlags flags = const FormQuestionFlags(),
    int? sortIndex,
    bool active = true,
  }) async {
    final now = FieldValue.serverTimestamp();
    final resolvedSort = sortIndex ?? await _nextSortIndex();
    final docRef = await _questions.add({
      'prompt': prompt,
      'kind': kind.firestoreValue,
      'options': options.map((o) => o.toMap()).toList(),
      'defaultOptionId': defaultOptionId,
      'flags': flags.toMap(),
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
    final snapshot = await _questions.get();
    var max = -1;
    for (final doc in snapshot.docs) {
      final value = (doc.data()['sortIndex'] as num?)?.toInt() ?? 0;
      if (value > max) {
        max = value;
      }
    }
    return max + 1;
  }

  /// Partial update; always stamps `updatedAt`/`updatedBy`. Soft-deactivate
  /// via [active]; never hard-deletes.
  Future<void> updateQuestion({
    required String questionId,
    required String updatedBy,
    String? prompt,
    FormQuestionKind? kind,
    List<FormQuestionOption>? options,
    String? defaultOptionId,
    bool clearDefaultOptionId = false,
    FormQuestionFlags? flags,
    int? sortIndex,
    bool? active,
  }) async {
    final fields = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
    if (prompt != null) {
      fields['prompt'] = prompt;
    }
    if (kind != null) {
      fields['kind'] = kind.firestoreValue;
    }
    if (options != null) {
      fields['options'] = options.map((o) => o.toMap()).toList();
    }
    if (clearDefaultOptionId) {
      fields['defaultOptionId'] = null;
    } else if (defaultOptionId != null) {
      fields['defaultOptionId'] = defaultOptionId;
    }
    if (flags != null) {
      fields['flags'] = flags.toMap();
    }
    if (sortIndex != null) {
      fields['sortIndex'] = sortIndex;
    }
    if (active != null) {
      fields['active'] = active;
    }
    await _questions.doc(questionId).update(fields);
  }

  /// Rewrites `sortIndex` to match [orderedIds] (0..n-1) in a batch.
  Future<void> reorderQuestions({
    required List<String> orderedIds,
    required String updatedBy,
  }) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_questions.doc(orderedIds[i]), {
        'sortIndex': i,
        'updatedAt': now,
        'updatedBy': updatedBy,
      });
    }
    await batch.commit();
  }

  /// Live list sorted by `sortIndex` (client-side; avoids composite index).
  Stream<List<FormQuestion>> watchQuestions({bool activeOnly = false}) {
    final query =
        activeOnly ? _questions.where('active', isEqualTo: true) : _questions;
    return query.snapshots().map((snapshot) {
      final questions = snapshot.docs
          .map((doc) => FormQuestion.fromFirestore(doc.id, doc.data()))
          .toList();
      questions.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
      return questions;
    });
  }

  Future<List<FormQuestion>> listQuestions({bool activeOnly = false}) async {
    final query =
        activeOnly ? _questions.where('active', isEqualTo: true) : _questions;
    final snapshot = await query.get();
    final questions = snapshot.docs
        .map((doc) => FormQuestion.fromFirestore(doc.id, doc.data()))
        .toList();
    questions.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return questions;
  }
}
