import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/presence/parecer.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

FormQuestion _saidaQuestion({
  String id = 'q-saida',
  bool optional = false,
  FormQuestionKind kind = FormQuestionKind.choice,
}) {
  return FormQuestion(
    id: id,
    prompt: 'Pergunta $id',
    kind: kind,
    options: kind == FormQuestionKind.choice
        ? const [
            FormQuestionOption(id: 'bem', label: 'Bem'),
            FormQuestionOption(id: 'mal', label: 'Mal'),
          ]
        : const [],
    defaultOptionId: kind == FormQuestionKind.choice ? 'bem' : null,
    flags: FormQuestionFlags(saida: true, optional: optional),
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

  group('registerDeparture form-driven', () {
    test('sets departedAt, isOpen=false and writes answers with recordedPhase=saida',
        () async {
      final recordId = await openRecord();
      final question = _saidaQuestion();
      final departedAt = DateTime.utc(2026, 8, 30, 17);

      await repository.registerDeparture(
        recordId: recordId,
        departedAt: departedAt,
        updatedBy: 'uid-1',
        answers: [
          DepartureAnswerDraft(question: question, value: 'bem'),
        ],
      );

      final doc =
          await firestore.collection('presence_records').doc(recordId).get();
      final data = doc.data()!;
      expect(data['isOpen'], isFalse);
      expect(data['departedAt'], Timestamp.fromDate(departedAt));
      expect(data['updatedBy'], 'uid-1');

      final answers = await repository.listAnswers(recordId: recordId);
      expect(answers, hasLength(1));
      expect(answers.single.recordedPhase, RecordedPhase.saida);
      expect(answers.single.value, 'bem');
      expect(answers.single.questionSnapshot.id, 'q-saida');
      expect(answers.single.flagsSnapshot.saida, isTrue);
    });

    test('legacy parecer still closes the record (compat)', () async {
      final recordId = await openRecord();

      await repository.registerDeparture(
        recordId: recordId,
        departedAt: DateTime.utc(2026, 8, 30, 17),
        parecer: const Parecer(humor: ParecerHumor.irritado),
        updatedBy: 'uid-2',
      );

      final doc =
          await firestore.collection('presence_records').doc(recordId).get();
      expect(doc.data()!['isOpen'], isFalse);
      expect(doc.data()!['parecer']['humor'], 'irritado');
    });

    test('rejects departure when record already closed', () async {
      final recordId = await openRecord();
      await repository.registerDeparture(
        recordId: recordId,
        departedAt: DateTime.utc(2026, 8, 30, 16),
        updatedBy: 'uid-1',
        answers: [
          DepartureAnswerDraft(question: _saidaQuestion(), value: 'bem'),
        ],
      );

      expect(
        () => repository.registerDeparture(
          recordId: recordId,
          departedAt: DateTime.utc(2026, 8, 30, 18),
          updatedBy: 'uid-1',
        ),
        throwsA(isA<PresenceRecordClosedException>()),
      );
    });

    test('refuses new routine answers after exit', () async {
      final recordId = await openRecord();
      await repository.registerDeparture(
        recordId: recordId,
        departedAt: DateTime.utc(2026, 8, 30, 16),
        updatedBy: 'uid-1',
        answers: [
          DepartureAnswerDraft(question: _saidaQuestion(), value: 'mal'),
        ],
      );

      expect(
        () => repository.registerAnswer(
          recordId: recordId,
          question: FormQuestion(
            id: 'q-dia',
            prompt: 'Durante?',
            kind: FormQuestionKind.text,
            options: const [],
            flags: const FormQuestionFlags(duranteDia: true),
            sortIndex: 0,
            active: true,
          ),
          value: 'depois',
          recordedPhase: RecordedPhase.duranteDia,
          createdBy: 'uid-1',
        ),
        throwsA(isA<PresenceRecordClosedException>()),
      );
    });
  });
}
