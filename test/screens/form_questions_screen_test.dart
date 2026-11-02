import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/forms/form_question_repository.dart';
import 'package:conecta_creche/screens/form_questions_screen.dart';
import 'package:conecta_creche/users/user_profile.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile(UserRole role) => UserProfile(
      uid: 'uid-${role.name}',
      role: role,
      displayName: role.label,
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  late FakeFirebaseFirestore firestore;
  late FormQuestionRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FormQuestionRepository(firestore: firestore);
  });

  testWidgets('blocks access below gestão', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FormQuestionsScreen(
          profile: _profile(UserRole.cuidador),
          formQuestionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Você não tem permissão para configurar formulários.'),
      findsOneWidget,
    );
  });

  testWidgets('gestão sees questions with badges and caregiver filters',
      (tester) async {
    await repository.createQuestion(
      prompt: 'Comeu?',
      kind: FormQuestionKind.choice,
      options: const [
        FormQuestionOption(id: 'sim', label: 'Sim'),
        FormQuestionOption(id: 'nao', label: 'Não'),
      ],
      flags: const FormQuestionFlags(
        saida: true,
        optional: true,
        incident: true,
      ),
      createdBy: 'u1',
    );
    await repository.createQuestion(
      prompt: 'Nota oculta',
      kind: FormQuestionKind.text,
      flags: const FormQuestionFlags(duranteDia: true, oculta: true),
      createdBy: 'u1',
    );

    await tester.pumpWidget(
      _wrap(
        FormQuestionsScreen(
          profile: _profile(UserRole.gestao),
          formQuestionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comeu?'), findsOneWidget);
    expect(find.text('Nota oculta'), findsOneWidget);
    expect(find.text('Opcional'), findsWidgets);
    expect(find.text('Incidente'), findsWidgets);
    expect(find.text('Saída'), findsWidgets);
    expect(find.text('Durante o dia'), findsWidgets);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilterChip, 'Ocultas'));
    await tester.pumpAndSettle();

    expect(find.text('Nota oculta'), findsOneWidget);
    expect(find.text('Comeu?'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Saída'));
    await tester.pumpAndSettle();

    expect(find.text('Comeu?'), findsOneWidget);
    expect(find.text('Nota oculta'), findsNothing);
  });

  testWidgets('gestão can create a question via dialog', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FormQuestionsScreen(
          profile: _profile(UserRole.gestao),
          formQuestionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Humor?');
    await tester.enterText(
      find.widgetWithText(TextField, 'Opções (uma por linha)'),
      'Bem\nNeutro',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Humor?'), findsOneWidget);
    final listed = await repository.listQuestions();
    expect(listed.single.prompt, 'Humor?');
    expect(listed.single.options.map((o) => o.label), ['Bem', 'Neutro']);
  });
}
