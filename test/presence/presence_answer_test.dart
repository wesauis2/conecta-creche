import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecordedPhase', () {
    test('round-trips firestore values', () {
      expect(RecordedPhase.duranteDia.firestoreValue, 'durante_dia');
      expect(RecordedPhase.saida.firestoreValue, 'saida');
      expect(RecordedPhase.fromFirestore('durante_dia'), RecordedPhase.duranteDia);
      expect(RecordedPhase.fromFirestore('saida'), RecordedPhase.saida);
      expect(RecordedPhase.fromFirestore('unknown'), RecordedPhase.duranteDia);
    });
  });

  group('PresenceAnswer.fromFirestore', () {
    test('maps snapshot, value, flags, phase and audit', () {
      final answer = PresenceAnswer.fromFirestore('a1', {
        'questionSnapshot': {
          'id': 'q1',
          'prompt': 'Temperatura alta?',
          'kind': 'choice',
          'options': [
            {'id': 'sim', 'label': 'Sim'},
            {'id': 'nao', 'label': 'Não'},
          ],
          'defaultOptionId': 'nao',
        },
        'value': 'sim',
        'flagsSnapshot': {
          'durante_dia': true,
          'saida': false,
          'oculta': false,
          'incident': true,
          'optional': true,
        },
        'recordedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 30, 14)),
        'recordedPhase': 'durante_dia',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 30, 14)),
        'createdBy': 'uid-1',
        'updatedAt': null,
        'updatedBy': null,
      });

      expect(answer.id, 'a1');
      expect(answer.questionSnapshot.id, 'q1');
      expect(answer.questionSnapshot.prompt, 'Temperatura alta?');
      expect(answer.questionSnapshot.kind, FormQuestionKind.choice);
      expect(answer.value, 'sim');
      expect(answer.flagsSnapshot.incident, isTrue);
      expect(answer.flagsSnapshot.duranteDia, isTrue);
      expect(answer.displayValue, 'Sim');
      expect(answer.recordedPhase, RecordedPhase.duranteDia);
      expect(answer.createdBy, 'uid-1');
      expect(answer.updatedBy, isNull);
      expect(answer.updatedAt, isNull);
    });
  });

  group('PresenceAnswer.toCreateMap', () {
    test('writes snapshots, phase, value and create audit; update fields null',
        () {
      final question = FormQuestion(
        id: 'q1',
        prompt: 'Machucou?',
        kind: FormQuestionKind.text,
        options: const [],
        flags: const FormQuestionFlags(
          duranteDia: true,
          incident: true,
        ),
        sortIndex: 0,
        active: true,
      );

      final map = PresenceAnswer.toCreateMap(
        question: question,
        value: 'Joelho esquerdo',
        recordedPhase: RecordedPhase.duranteDia,
        recordedAt: DateTime.utc(2026, 8, 30, 15),
        createdBy: 'uid-2',
      );

      expect(map['questionSnapshot']['id'], 'q1');
      expect(map['questionSnapshot']['prompt'], 'Machucou?');
      expect(map['value'], 'Joelho esquerdo');
      expect(map['flagsSnapshot']['incident'], isTrue);
      expect(map['flagsSnapshot']['durante_dia'], isTrue);
      expect(map['recordedPhase'], 'durante_dia');
      expect(map['createdBy'], 'uid-2');
      expect(map['updatedBy'], isNull);
      expect(map['updatedAt'], isNull);
      expect(map['recordedAt'], Timestamp.fromDate(DateTime.utc(2026, 8, 30, 15)));
    });
  });

  group('AnswerEditGuard', () {
    final createdAt = DateTime.utc(2026, 8, 30, 12);

    test('allows edit within 24h', () {
      expect(
        AnswerEditGuard.canEdit(
          createdAt: createdAt,
          now: createdAt.add(const Duration(hours: 23, minutes: 59)),
        ),
        isTrue,
      );
    });

    test('blocks edit after 24h', () {
      expect(
        AnswerEditGuard.canEdit(
          createdAt: createdAt,
          now: createdAt.add(const Duration(hours: 24, minutes: 1)),
        ),
        isFalse,
      );
      expect(
        () => AnswerEditGuard.ensureCanEdit(
          createdAt: createdAt,
          now: createdAt.add(const Duration(hours: 25)),
        ),
        throwsA(isA<AnswerEditWindowException>()),
      );
    });
  });
}
