import 'package:conecta_creche/forms/default_form_questions.dart';
import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/forms/form_question_repository.dart';
import 'package:conecta_creche/forms/form_question_seeder.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaultFormQuestionsPackage', () {
    test('cobre RF0012–0015 e incidentes com seedKeys únicos', () {
      final package = defaultFormQuestionsPackage();
      final keys = package.map((q) => q.seedKey).toList();

      expect(keys.toSet().length, keys.length);
      expect(keys.where((k) => k.startsWith('rf0012.')), isNotEmpty);
      expect(keys.where((k) => k.startsWith('rf0013.')), isNotEmpty);
      expect(keys.where((k) => k.startsWith('rf0014.')), isNotEmpty);
      expect(keys.where((k) => k.startsWith('rf0015.')), isNotEmpty);
      expect(keys.where((k) => k.startsWith('incident.')), isNotEmpty);
    });

    test('flags tipicas por tema', () {
      final byKey = {
        for (final q in defaultFormQuestionsPackage()) q.seedKey: q,
      };

      expect(byKey['rf0012.atividade']!.flags.duranteDia, isTrue);
      expect(byKey['rf0012.descricao']!.flags.optional, isTrue);

      expect(byKey['rf0013.comeu']!.flags.duranteDia, isTrue);
      expect(byKey['rf0013.comeu']!.flags.saida, isTrue);

      expect(byKey['rf0014.descansou']!.flags.duranteDia, isTrue);
      expect(byKey['rf0014.descansou']!.flags.saida, isTrue);

      expect(byKey['rf0015.comportamento']!.flags.duranteDia, isTrue);
      expect(byKey['rf0015.observacao']!.flags.optional, isTrue);

      expect(byKey['incident.saude']!.flags.incident, isTrue);
      expect(byKey['incident.saude']!.flags.duranteDia, isTrue);
      expect(byKey['incident.anexo']!.kind, FormQuestionKind.image);
    });
  });

  group('FormQuestion.seedKey', () {
    test('fromFirestore lê seedKey', () {
      final q = FormQuestion.fromFirestore('id-1', {
        'prompt': 'X',
        'kind': 'text',
        'seedKey': 'rf0012.atividade',
        'flags': {'durante_dia': true},
        'sortIndex': 0,
        'active': true,
      });
      expect(q.seedKey, 'rf0012.atividade');
    });
  });

  group('FormQuestionSeeder', () {
    late FakeFirebaseFirestore firestore;
    late FormQuestionRepository repository;
    late FormQuestionSeeder seeder;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FormQuestionRepository(firestore: firestore);
      seeder = FormQuestionSeeder(
        repository: repository,
        actorUid: 'tester',
      );
    });

    test('modo seguro cria pacote em coleção vazia', () async {
      final result = await seeder.seed();
      final package = defaultFormQuestionsPackage();

      expect(result.replace, isFalse);
      expect(result.created, package.length);
      expect(result.skipped, 0);

      final listed = await repository.listQuestions(activeOnly: true);
      expect(listed.length, package.length);
      expect(
        listed.map((q) => q.seedKey).toSet(),
        defaultFormQuestionSeedKeys(),
      );
    });

    test('modo seguro é idempotente via seedKey', () async {
      await seeder.seed();
      final second = await seeder.seed();

      expect(second.created, 0);
      expect(second.skipped, defaultFormQuestionsPackage().length);

      final listed = await repository.listQuestions();
      expect(listed.length, defaultFormQuestionsPackage().length);
    });

    test('modo seguro só completa seedKeys ausentes', () async {
      await repository.createQuestion(
        prompt: 'Custom',
        kind: FormQuestionKind.text,
        createdBy: 'gestao',
        flags: const FormQuestionFlags(duranteDia: true),
      );
      await repository.createQuestion(
        prompt: 'Atividade seed parcial',
        kind: FormQuestionKind.choice,
        options: const [
          FormQuestionOption(id: 'sim', label: 'Sim'),
          FormQuestionOption(id: 'nao', label: 'Não'),
        ],
        createdBy: 'gestao',
        seedKey: 'rf0012.atividade',
        flags: const FormQuestionFlags(duranteDia: true),
      );

      final result = await seeder.seed();
      final package = defaultFormQuestionsPackage();

      expect(result.created, package.length - 1);
      expect(result.skipped, 1);

      final listed = await repository.listQuestions();
      expect(listed.length, package.length + 1); // custom + defaults
      expect(
        listed.where((q) => q.seedKey == 'rf0012.atividade').length,
        1,
      );
    });

    test('--replace desativa ativas e regrava defaults', () async {
      await repository.createQuestion(
        prompt: 'Custom ativa',
        kind: FormQuestionKind.text,
        createdBy: 'gestao',
        flags: const FormQuestionFlags(saida: true),
      );
      await seeder.seed();

      final before = await repository.listQuestions(activeOnly: true);
      expect(before.length, defaultFormQuestionsPackage().length + 1);

      final result = await seeder.seed(replace: true);
      expect(result.replace, isTrue);
      expect(result.deactivated, before.length);
      expect(
        result.created + result.updated,
        defaultFormQuestionsPackage().length,
      );

      final active = await repository.listQuestions(activeOnly: true);
      expect(active.length, defaultFormQuestionsPackage().length);
      expect(
        active.every((q) => q.seedKey != null && q.seedKey!.isNotEmpty),
        isTrue,
      );
      expect(
        active.map((q) => q.seedKey).toSet(),
        defaultFormQuestionSeedKeys(),
      );

      // Custom permanece, porém inativa.
      final all = await repository.listQuestions();
      final custom = all.where((q) => q.seedKey == null).toList();
      expect(custom.length, 1);
      expect(custom.single.active, isFalse);
      expect(custom.single.prompt, 'Custom ativa');
    });

    test('--replace atualiza conteúdo do seedKey existente', () async {
      await seeder.seed();
      final first = (await repository.listQuestions())
          .firstWhere((q) => q.seedKey == 'rf0012.atividade');

      await repository.updateQuestion(
        questionId: first.id,
        updatedBy: 'gestao',
        prompt: 'Pergunta alterada na gestão',
      );

      final result = await seeder.seed(replace: true);
      expect(result.updated, greaterThan(0));

      final restored = (await repository.listQuestions(activeOnly: true))
          .firstWhere((q) => q.seedKey == 'rf0012.atividade');
      expect(restored.prompt, 'Atividade realizada?');
      expect(restored.active, isTrue);
    });
  });
}
