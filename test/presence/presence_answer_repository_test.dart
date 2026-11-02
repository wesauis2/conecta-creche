import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/presence/parecer.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

FormQuestion _question({
  String id = 'q1',
  bool incident = false,
  bool duranteDia = true,
  bool oculta = false,
  FormQuestionKind kind = FormQuestionKind.choice,
}) {
  return FormQuestion(
    id: id,
    prompt: 'Pergunta $id',
    kind: kind,
    options: kind == FormQuestionKind.choice || kind == FormQuestionKind.choiceOther
        ? const [
            FormQuestionOption(id: 'sim', label: 'Sim'),
            FormQuestionOption(id: 'nao', label: 'Não'),
          ]
        : const [],
    defaultOptionId: kind == FormQuestionKind.choice ? 'nao' : null,
    flags: FormQuestionFlags(
      duranteDia: duranteDia,
      oculta: oculta,
      incident: incident,
    ),
    sortIndex: 0,
    active: true,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late PresenceRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = PresenceRepository(firestore: firestore);
  });

  Future<String> openRecord() => repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'uid-1',
      );

  group('registerAnswer', () {
    test('creates answer under open record with snapshots and audit', () async {
      final recordId = await openRecord();
      final question = _question(incident: true);

      final answerId = await repository.registerAnswer(
        recordId: recordId,
        question: question,
        value: 'sim',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'uid-1',
        recordedAt: DateTime.utc(2026, 8, 30, 14),
      );

      final doc = await firestore
          .collection('presence_records')
          .doc(recordId)
          .collection('answers')
          .doc(answerId)
          .get();
      final data = doc.data()!;

      expect(data['questionSnapshot']['id'], 'q1');
      expect(data['questionSnapshot']['prompt'], 'Pergunta q1');
      expect(data['value'], 'sim');
      expect(data['flagsSnapshot']['incident'], isTrue);
      expect(data['recordedPhase'], 'durante_dia');
      expect(data['createdBy'], 'uid-1');
      expect(data['updatedBy'], isNull);
      expect(data['updatedAt'], isNull);
    });

    test('rejects new answers when record is closed', () async {
      final recordId = await openRecord();
      await repository.registerDeparture(
        recordId: recordId,
        departedAt: DateTime.utc(2026, 8, 30, 16),
        parecer: const Parecer(),
        updatedBy: 'uid-1',
      );

      expect(
        () => repository.registerAnswer(
          recordId: recordId,
          question: _question(),
          value: 'sim',
          recordedPhase: RecordedPhase.duranteDia,
          createdBy: 'uid-1',
        ),
        throwsA(isA<PresenceRecordClosedException>()),
      );
    });
  });

  group('updateAnswer edit window', () {
    test('within 24h updates value and stamps updatedBy/updatedAt', () async {
      final recordId = await openRecord();
      final createdAt = DateTime.utc(2026, 8, 30, 14);
      final answerId = await repository.registerAnswer(
        recordId: recordId,
        question: _question(),
        value: 'nao',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'uid-1',
        recordedAt: createdAt,
      );

      // FakeFirestore serverTimestamp needs a concrete stamp for assert;
      // force createdAt on the doc so the guard uses it.
      await firestore
          .collection('presence_records')
          .doc(recordId)
          .collection('answers')
          .doc(answerId)
          .update({'createdAt': Timestamp.fromDate(createdAt)});

      await repository.updateAnswer(
        recordId: recordId,
        answerId: answerId,
        value: 'sim',
        updatedBy: 'uid-2',
        now: createdAt.add(const Duration(hours: 2)),
      );

      final doc = await firestore
          .collection('presence_records')
          .doc(recordId)
          .collection('answers')
          .doc(answerId)
          .get();
      final data = doc.data()!;

      expect(data['value'], 'sim');
      expect(data['updatedBy'], 'uid-2');
      expect(data['updatedAt'], isNotNull);
    });

    test('after 24h rejects edit', () async {
      final recordId = await openRecord();
      final createdAt = DateTime.utc(2026, 8, 30, 14);
      final answerId = await repository.registerAnswer(
        recordId: recordId,
        question: _question(),
        value: 'nao',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'uid-1',
        recordedAt: createdAt,
      );
      await firestore
          .collection('presence_records')
          .doc(recordId)
          .collection('answers')
          .doc(answerId)
          .update({'createdAt': Timestamp.fromDate(createdAt)});

      expect(
        () => repository.updateAnswer(
          recordId: recordId,
          answerId: answerId,
          value: 'sim',
          updatedBy: 'uid-2',
          now: createdAt.add(const Duration(hours: 25)),
        ),
        throwsA(isA<AnswerEditWindowException>()),
      );
    });
  });

  group('listAnswers', () {
    test('returns answers ordered by recordedAt', () async {
      final recordId = await openRecord();
      await repository.registerAnswer(
        recordId: recordId,
        question: _question(id: 'q-late'),
        value: 'sim',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'uid-1',
        recordedAt: DateTime.utc(2026, 8, 30, 16),
      );
      await repository.registerAnswer(
        recordId: recordId,
        question: _question(id: 'q-early'),
        value: 'texto',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'uid-1',
        recordedAt: DateTime.utc(2026, 8, 30, 13),
      );

      final answers = await repository.listAnswers(recordId: recordId);

      expect(answers.map((a) => a.questionSnapshot.id), ['q-early', 'q-late']);
    });
  });
}
