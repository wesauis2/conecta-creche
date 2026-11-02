import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/incidentes_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

FormQuestion _incidentQuestion({String id = 'q-inc'}) {
  return FormQuestion(
    id: id,
    prompt: 'Temperatura elevada?',
    kind: FormQuestionKind.choice,
    options: const [
      FormQuestionOption(id: 'sim', label: 'Sim'),
      FormQuestionOption(id: 'nao', label: 'Não'),
    ],
    defaultOptionId: 'nao',
    flags: const FormQuestionFlags(duranteDia: true, incident: true),
    sortIndex: 0,
    active: true,
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ChildRepository childRepository;
  late PresenceRepository presenceRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    childRepository = ChildRepository(firestore: firestore);
    presenceRepository = PresenceRepository(firestore: firestore);
  });

  testWidgets('lists incident answers with child name and prompt',
      (tester) async {
    final sofiaId =
        await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
    await childRepository.createChild(name: 'Pedro', createdBy: 'u1');

    final recordId = await presenceRepository.registerArrival(
      childId: sofiaId,
      dayKey: '2026-08-30',
      arrivedAt: DateTime.utc(2026, 8, 30, 12),
      createdBy: 'u1',
    );
    await presenceRepository.registerAnswer(
      recordId: recordId,
      question: _incidentQuestion(),
      value: 'sim',
      recordedPhase: RecordedPhase.duranteDia,
      createdBy: 'u1',
      recordedAt: DateTime.utc(2026, 8, 30, 14),
    );
    await presenceRepository.registerAnswer(
      recordId: recordId,
      question: FormQuestion(
        id: 'q-normal',
        prompt: 'Almoçou bem?',
        kind: FormQuestionKind.choice,
        options: const [
          FormQuestionOption(id: 'sim', label: 'Sim'),
          FormQuestionOption(id: 'nao', label: 'Não'),
        ],
        flags: const FormQuestionFlags(duranteDia: true),
        sortIndex: 1,
        active: true,
      ),
      value: 'sim',
      recordedPhase: RecordedPhase.duranteDia,
      createdBy: 'u1',
      recordedAt: DateTime.utc(2026, 8, 30, 15),
    );

    await tester.pumpWidget(
      _wrap(
        IncidentesScreen(
          presenceRepository: presenceRepository,
          childRepository: childRepository,
          initialDayKey: '2026-08-30',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('incidentes-list')), findsOneWidget);
    expect(find.text('Sofia'), findsWidgets);
    expect(find.textContaining('Temperatura elevada?'), findsOneWidget);
    expect(find.textContaining('Sim'), findsWidgets);
    expect(find.textContaining('Almoçou bem?'), findsNothing);
  });

  testWidgets('empty filter shows empty state', (tester) async {
    await childRepository.createChild(name: 'Sofia', createdBy: 'u1');

    await tester.pumpWidget(
      _wrap(
        IncidentesScreen(
          presenceRepository: presenceRepository,
          childRepository: childRepository,
          initialDayKey: '2026-08-30',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('incidentes-empty')), findsOneWidget);
    expect(find.text('Nenhum incidente neste filtro.'), findsOneWidget);
  });

  testWidgets('child filter restricts the list', (tester) async {
    final sofiaId =
        await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
    final pedroId =
        await childRepository.createChild(name: 'Pedro', createdBy: 'u1');

    Future<void> seedIncident(String childId) async {
      final recordId = await presenceRepository.registerArrival(
        childId: childId,
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'u1',
      );
      await presenceRepository.registerAnswer(
        recordId: recordId,
        question: _incidentQuestion(id: 'q-$childId'),
        value: 'sim',
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: 'u1',
        recordedAt: DateTime.utc(2026, 8, 30, 14),
      );
    }

    await seedIncident(sofiaId);
    await seedIncident(pedroId);

    await tester.pumpWidget(
      _wrap(
        IncidentesScreen(
          presenceRepository: presenceRepository,
          childRepository: childRepository,
          initialDayKey: '2026-08-30',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sofia'), findsWidgets);
    expect(find.text('Pedro'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('incidentes-child-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sofia').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Temperatura elevada?'), findsOneWidget);
    // List tile title for Sofia remains; Pedro should leave the list.
    final list = find.byKey(const ValueKey('incidentes-list'));
    expect(
      find.descendant(of: list, matching: find.text('Sofia')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: list, matching: find.text('Pedro')),
      findsNothing,
    );
  });
}
