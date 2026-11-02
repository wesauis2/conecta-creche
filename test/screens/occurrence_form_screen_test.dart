import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/forms/form_question_repository.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/occurrence_form_screen.dart';
import 'package:conecta_creche/screens/presence_day_screen.dart';
import 'package:conecta_creche/users/user_profile.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dayKey = '2026-08-30';

UserProfile _profile() => const UserProfile(
      uid: 'uid-cuidador',
      role: UserRole.cuidador,
      displayName: 'Cuidador',
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  late FakeFirebaseFirestore firestore;
  late ChildRepository childRepository;
  late PresenceRepository presenceRepository;
  late FormQuestionRepository formQuestionRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    childRepository = ChildRepository(firestore: firestore);
    presenceRepository = PresenceRepository(firestore: firestore);
    formQuestionRepository = FormQuestionRepository(firestore: firestore);
  });

  testWidgets(
      'open record offers ocorrência; short list hides ocultas until expanded',
      (tester) async {
    final childId =
        await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
    final recordId = await presenceRepository.registerArrival(
      childId: childId,
      dayKey: _dayKey,
      arrivedAt: DateTime.utc(2026, 8, 30, 12),
      createdBy: 'u1',
    );

    await formQuestionRepository.createQuestion(
      prompt: 'Temperatura?',
      kind: FormQuestionKind.choice,
      options: const [
        FormQuestionOption(id: 'sim', label: 'Sim'),
        FormQuestionOption(id: 'nao', label: 'Não'),
      ],
      flags: const FormQuestionFlags(duranteDia: true, incident: true),
      createdBy: 'u1',
    );
    await formQuestionRepository.createQuestion(
      prompt: 'Nota oculta',
      kind: FormQuestionKind.text,
      flags: const FormQuestionFlags(duranteDia: true, oculta: true),
      createdBy: 'u1',
    );
    await formQuestionRepository.createQuestion(
      prompt: 'Só na saída',
      kind: FormQuestionKind.text,
      flags: const FormQuestionFlags(saida: true),
      createdBy: 'u1',
    );

    await tester.pumpWidget(
      _wrap(
        PresenceDayScreen(
          profile: _profile(),
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          formQuestionRepository: formQuestionRepository,
          dayKey: _dayKey,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sofia'));
    await tester.pumpAndSettle();

    expect(find.text('Ocorrência'), findsOneWidget);
    expect(find.text('Saída'), findsWidgets);

    await tester.tap(find.text('Ocorrência'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ocorrência · Sofia'), findsOneWidget);
    expect(find.text('Temperatura?'), findsOneWidget);
    expect(find.text('Nota oculta'), findsNothing);
    expect(find.text('Só na saída'), findsNothing);

    await tester.tap(find.text('Mais perguntas'));
    await tester.pumpAndSettle();
    expect(find.text('Nota oculta'), findsOneWidget);

    await tester.tap(find.text('Temperatura?'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sim'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    final answers =
        await presenceRepository.listAnswers(recordId: recordId);
    expect(answers, hasLength(1));
    expect(answers.single.value, 'sim');
    expect(answers.single.flagsSnapshot.incident, isTrue);
    expect(answers.single.questionSnapshot.prompt, 'Temperatura?');
  });

  testWidgets('OccurrenceFormScreen alone lists durante_dia questions',
      (tester) async {
    await formQuestionRepository.createQuestion(
      prompt: 'Machucou?',
      kind: FormQuestionKind.text,
      flags: const FormQuestionFlags(duranteDia: true),
      createdBy: 'u1',
    );

    await tester.pumpWidget(
      _wrap(
        OccurrenceFormScreen(
          profile: _profile(),
          recordId: 'rec-1',
          childName: 'Ana',
          formQuestionRepository: formQuestionRepository,
          presenceRepository: presenceRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Machucou?'), findsOneWidget);
    expect(find.textContaining('Ocorrência · Ana'), findsOneWidget);
  });
}
