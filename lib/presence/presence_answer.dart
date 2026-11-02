import 'package:cloud_firestore/cloud_firestore.dart';

import '../forms/form_question.dart';

/// Fase em que a resposta foi registrada. Ver CONTEXT.md "Resposta (answer)".
enum RecordedPhase {
  duranteDia,
  saida;

  String get firestoreValue => switch (this) {
        RecordedPhase.duranteDia => 'durante_dia',
        RecordedPhase.saida => 'saida',
      };

  static RecordedPhase fromFirestore(String? value) {
    if (value == 'saida') {
      return RecordedPhase.saida;
    }
    return RecordedPhase.duranteDia;
  }
}

/// Snapshot estável da pergunta embutido na answer (histórico independente
/// do template atual). Reusa [FormQuestionKind] / [FormQuestionOption].
class QuestionSnapshot {
  const QuestionSnapshot({
    required this.id,
    required this.prompt,
    required this.kind,
    required this.options,
    this.defaultOptionId,
  });

  final String id;
  final String prompt;
  final FormQuestionKind kind;
  final List<FormQuestionOption> options;
  final String? defaultOptionId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'prompt': prompt,
        'kind': kind.firestoreValue,
        'options': options.map((o) => o.toMap()).toList(),
        'defaultOptionId': defaultOptionId,
      };

  factory QuestionSnapshot.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = <FormQuestionOption>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map<String, dynamic>) {
          options.add(FormQuestionOption.fromMap(item));
        } else if (item is Map) {
          options.add(
            FormQuestionOption.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return QuestionSnapshot(
      id: map['id'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      kind: FormQuestionKind.fromFirestore(map['kind'] as String?),
      options: options,
      defaultOptionId: map['defaultOptionId'] as String?,
    );
  }

  factory QuestionSnapshot.fromQuestion(FormQuestion question) {
    return QuestionSnapshot(
      id: question.id,
      prompt: question.prompt,
      kind: question.kind,
      options: question.options,
      defaultOptionId: question.defaultOptionId,
    );
  }
}

/// Resposta persistida em `presence_records/{id}/answers/{answerId}`.
/// Ver CONTEXT.md "Resposta (answer)" / "Incidente" / "Auditoria de registro".
class PresenceAnswer {
  const PresenceAnswer({
    required this.id,
    required this.questionSnapshot,
    required this.value,
    required this.flagsSnapshot,
    required this.recordedPhase,
    this.recordedAt,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final QuestionSnapshot questionSnapshot;

  /// Valor conforme [FormQuestionKind] (optionId, texto, mapa choice_other, refs).
  final Object? value;
  final FormQuestionFlags flagsSnapshot;
  final RecordedPhase recordedPhase;
  final DateTime? recordedAt;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  bool get isIncident => flagsSnapshot.incident;

  factory PresenceAnswer.fromFirestore(String id, Map<String, dynamic> data) {
    final snapshotRaw = data['questionSnapshot'];
    final snapshotMap = snapshotRaw is Map<String, dynamic>
        ? snapshotRaw
        : snapshotRaw is Map
            ? Map<String, dynamic>.from(snapshotRaw)
            : <String, dynamic>{};

    final flagsRaw = data['flagsSnapshot'];
    final flagsMap = flagsRaw is Map<String, dynamic>
        ? flagsRaw
        : flagsRaw is Map
            ? Map<String, dynamic>.from(flagsRaw)
            : null;

    return PresenceAnswer(
      id: id,
      questionSnapshot: QuestionSnapshot.fromMap(snapshotMap),
      value: data['value'],
      flagsSnapshot: FormQuestionFlags.fromMap(flagsMap),
      recordedPhase: RecordedPhase.fromFirestore(data['recordedPhase'] as String?),
      recordedAt: (data['recordedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  /// Campos escritos na criação. `updatedAt`/`updatedBy` ficam nulos até a
  /// primeira edição (janela de 24h).
  static Map<String, dynamic> toCreateMap({
    required FormQuestion question,
    required Object? value,
    required RecordedPhase recordedPhase,
    required String createdBy,
    required DateTime recordedAt,
  }) {
    final now = FieldValue.serverTimestamp();
    return {
      'questionSnapshot': QuestionSnapshot.fromQuestion(question).toMap(),
      'value': value,
      'flagsSnapshot': question.flags.toMap(),
      'recordedAt': Timestamp.fromDate(recordedAt),
      'recordedPhase': recordedPhase.firestoreValue,
      'createdAt': now,
      'createdBy': createdBy,
      'updatedAt': null,
      'updatedBy': null,
    };
  }
}

/// Janela de edição de answers (24h a partir de `createdAt`).
class AnswerEditGuard {
  AnswerEditGuard._();

  static const Duration editWindow = Duration(hours: 24);

  static bool canEdit({
    required DateTime createdAt,
    required DateTime now,
  }) {
    final deadline = createdAt.add(editWindow);
    return !now.isAfter(deadline);
  }

  static void ensureCanEdit({
    required DateTime createdAt,
    required DateTime now,
  }) {
    if (!canEdit(createdAt: createdAt, now: now)) {
      throw AnswerEditWindowException(createdAt: createdAt, now: now);
    }
  }
}

/// Thrown when Cuidador+ tenta editar uma answer fora da janela de 24h.
class AnswerEditWindowException implements Exception {
  AnswerEditWindowException({required this.createdAt, required this.now});

  final DateTime createdAt;
  final DateTime now;

  @override
  String toString() =>
      'AnswerEditWindowException: edição permitida só até '
      '${createdAt.add(AnswerEditGuard.editWindow)} (agora: $now)';
}

/// Thrown when se tenta gravar nova answer em registro já fechado.
class PresenceRecordClosedException implements Exception {
  PresenceRecordClosedException({required this.recordId});

  final String recordId;

  @override
  String toString() =>
      'PresenceRecordClosedException: registro $recordId está fechado';
}
