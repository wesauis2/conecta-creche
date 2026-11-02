import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/forms/form_question_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FormQuestionRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FormQuestionRepository(firestore: firestore);
  });

  group('createQuestion', () {
    test('creates with kind, options, flags, sortIndex and audit', () async {
      final id = await repository.createQuestion(
        prompt: 'Comeu?',
        kind: FormQuestionKind.choice,
        options: const [
          FormQuestionOption(id: 'sim', label: 'Sim'),
          FormQuestionOption(id: 'nao', label: 'Não'),
        ],
        defaultOptionId: 'sim',
        flags: const FormQuestionFlags(saida: true),
        createdBy: 'uid-1',
      );

      final doc = await firestore.collection('form_questions').doc(id).get();
      final data = doc.data()!;

      expect(data['prompt'], 'Comeu?');
      expect(data['kind'], 'choice');
      expect(data['defaultOptionId'], 'sim');
      expect(data['flags']['saida'], isTrue);
      expect(data['sortIndex'], 0);
      expect(data['active'], isTrue);
      expect(data['createdBy'], 'uid-1');
      expect(data['updatedBy'], 'uid-1');
      expect(data['createdAt'], isNotNull);
      expect((data['options'] as List).length, 2);
    });

    test('assigns incremental sortIndex by default', () async {
      final a = await repository.createQuestion(
        prompt: 'A',
        kind: FormQuestionKind.text,
        createdBy: 'u1',
      );
      final b = await repository.createQuestion(
        prompt: 'B',
        kind: FormQuestionKind.text,
        createdBy: 'u1',
      );

      final docA = await firestore.collection('form_questions').doc(a).get();
      final docB = await firestore.collection('form_questions').doc(b).get();
      expect(docA.data()!['sortIndex'], 0);
      expect(docB.data()!['sortIndex'], 1);
    });

    test('persists choice_other kind', () async {
      final id = await repository.createQuestion(
        prompt: 'Outro?',
        kind: FormQuestionKind.choiceOther,
        createdBy: 'u1',
      );
      final doc = await firestore.collection('form_questions').doc(id).get();
      expect(doc.data()!['kind'], 'choice_other');
    });
  });

  group('updateQuestion', () {
    test('updates prompt, flags and stamps audit', () async {
      final id = await repository.createQuestion(
        prompt: 'Antes',
        kind: FormQuestionKind.text,
        createdBy: 'uid-1',
      );

      await repository.updateQuestion(
        questionId: id,
        prompt: 'Depois',
        flags: const FormQuestionFlags(duranteDia: true, optional: true),
        updatedBy: 'uid-2',
      );

      final doc = await firestore.collection('form_questions').doc(id).get();
      final data = doc.data()!;
      expect(data['prompt'], 'Depois');
      expect(data['flags']['durante_dia'], isTrue);
      expect(data['flags']['optional'], isTrue);
      expect(data['updatedBy'], 'uid-2');
    });

    test('soft-deactivates without hard delete', () async {
      final id = await repository.createQuestion(
        prompt: 'X',
        kind: FormQuestionKind.text,
        createdBy: 'u1',
      );

      await repository.updateQuestion(
        questionId: id,
        active: false,
        updatedBy: 'u-gestao',
      );

      final doc = await firestore.collection('form_questions').doc(id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['active'], isFalse);
    });
  });

  group('reorderQuestions', () {
    test('rewrites sortIndex to match ordered ids', () async {
      final a = await repository.createQuestion(
        prompt: 'A',
        kind: FormQuestionKind.text,
        createdBy: 'u1',
      );
      final b = await repository.createQuestion(
        prompt: 'B',
        kind: FormQuestionKind.text,
        createdBy: 'u1',
      );
      final c = await repository.createQuestion(
        prompt: 'C',
        kind: FormQuestionKind.text,
        createdBy: 'u1',
      );

      await repository.reorderQuestions(
        orderedIds: [c, a, b],
        updatedBy: 'u-gestao',
      );

      final listed = await repository.listQuestions();
      expect(listed.map((q) => q.prompt), ['C', 'A', 'B']);
      expect(listed.map((q) => q.sortIndex), [0, 1, 2]);
    });
  });

  group('watchQuestions / listQuestions', () {
    test('emits sorted by sortIndex including inactive', () async {
      final z = await repository.createQuestion(
        prompt: 'Z',
        kind: FormQuestionKind.text,
        sortIndex: 2,
        createdBy: 'u1',
      );
      await repository.createQuestion(
        prompt: 'A',
        kind: FormQuestionKind.text,
        sortIndex: 0,
        createdBy: 'u1',
      );
      await repository.createQuestion(
        prompt: 'M',
        kind: FormQuestionKind.text,
        sortIndex: 1,
        createdBy: 'u1',
      );
      await repository.updateQuestion(
        questionId: z,
        active: false,
        updatedBy: 'u1',
      );

      final all = await repository.watchQuestions().first;
      expect(all.map((q) => q.prompt), ['A', 'M', 'Z']);
      expect(all.last.active, isFalse);

      final activeOnly =
          await repository.watchQuestions(activeOnly: true).first;
      expect(activeOnly.map((q) => q.prompt), ['A', 'M']);
    });
  });
}
