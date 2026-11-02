import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/forms/form_question_repository.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/exit_form_screen.dart';
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
      'exit form shows required saida, reuses day answers, extras for awareness',
      (tester) async {
    final recordId = await presenceRepository.registerArrival(
      childId: 'child-1',
      dayKey: _dayKey,
      arrivedAt: DateTime.utc(2026, 8, 30, 12),
      createdBy: 'u1',
    );

    final humorId = await formQuestionRepository.createQuestion(
      prompt: 'Humor na saída?',
      kind: FormQuestionKind.choice,
      options: const [
        FormQuestionOption(id: 'bem', label: 'Bem'),
        FormQuestionOption(id: 'mal', label: 'Mal'),
      ],
      defaultOptionId: 'bem',
      flags: const FormQuestionFlags(saida: true),
      createdBy: 'u1',
    );
    await formQuestionRepository.createQuestion(
      prompt: 'Observação opcional',
      kind: FormQuestionKind.text,
      flags: const FormQuestionFlags(saida: true, optional: true),
      createdBy: 'u1',
    );
    final tempId = await formQuestionRepository.createQuestion(
      prompt: 'Temperatura?',
      kind: FormQuestionKind.choice,
      options: const [
        FormQuestionOption(id: 'sim', label: 'Sim'),
        FormQuestionOption(id: 'nao', label: 'Não'),
      ],
      flags: const FormQuestionFlags(duranteDia: true, incident: true),
      createdBy: 'u1',
    );

    // Already answered during the day — should appear as reuse / awareness.
    final questions = await formQuestionRepository.listQuestions();
    final tempQuestion = questions.firstWhere((q) => q.id == tempId);
    await presenceRepository.registerAnswer(
      recordId: recordId,
      question: tempQuestion,
      value: 'sim',
      recordedPhase: RecordedPhase.duranteDia,
      createdBy: 'u1',
      recordedAt: DateTime.utc(2026, 8, 30, 14),
    );

    await tester.pumpWidget(
      _wrap(
        ExitFormScreen(
          profile: _profile(),
          recordId: recordId,
          childName: 'Sofia',
          formQuestionRepository: formQuestionRepository,
          presenceRepository: presenceRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Saída · Sofia'), findsOneWidget);
    expect(find.text('Humor na saída?'), findsOneWidget);
    expect(find.textContaining('Observação opcional'), findsOneWidget);
    expect(find.textContaining('ciência'), findsWidgets);
    expect(find.text('Temperatura?'), findsOneWidget);
    expect(find.textContaining('Já registrado'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Mal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar saída'));
    await tester.pumpAndSettle();

    final records = await presenceRepository.listByDayKey(dayKey: _dayKey);
    expect(records.single.isOpen, isFalse);
    expect(records.single.departedAt, isNotNull);

    final answers = await presenceRepository.listAnswers(recordId: recordId);
    expect(answers.length, greaterThanOrEqualTo(2));
    final saidaAnswer = answers.where(
      (a) =>
          a.recordedPhase == RecordedPhase.saida &&
          a.questionSnapshot.id == humorId,
    );
    expect(saidaAnswer, hasLength(1));
    expect(saidaAnswer.single.value, 'mal');

    // No new answer for Temperatura (reused, not rewritten at saída).
    expect(
      answers.where((a) => a.questionSnapshot.id == tempId),
      hasLength(1),
    );
  });

  testWidgets('day screen saída uses exit form when forms are available',
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
      prompt: 'Comeu bem?',
      kind: FormQuestionKind.choice,
      options: const [
        FormQuestionOption(id: 'sim', label: 'Sim'),
        FormQuestionOption(id: 'nao', label: 'Não'),
      ],
      defaultOptionId: 'sim',
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
    await tester.tap(find.widgetWithText(FilledButton, 'Saída'));
    await tester.pumpAndSettle();

    // Confirm dialog then exit form (not legacy parecer labels).
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar saída'));
    await tester.pumpAndSettle();

    expect(find.text('Saída · Sofia'), findsOneWidget);
    expect(find.text('Comeu bem?'), findsOneWidget);
    expect(find.text('Chorou?'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Não'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar saída'));
    await tester.pumpAndSettle();

    final records = await presenceRepository.listByDayKey(dayKey: _dayKey);
    expect(records.single.isOpen, isFalse);
    final answers = await presenceRepository.listAnswers(recordId: recordId);
    expect(answers.single.recordedPhase, RecordedPhase.saida);
    expect(answers.single.value, 'nao');
  });
}
