import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/relatorios_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

FormQuestion _incidentQuestion() {
  return FormQuestion(
    id: 'q-inc',
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

  testWidgets('empty state quando responsável não tem vínculos', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RelatoriosScreen(
          responsibleUid: 'resp-1',
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          now: DateTime(2026, 11, 2, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('relatorios-empty')), findsOneWidget);
    expect(find.textContaining('Nenhuma criança vinculada'), findsOneWidget);
  });

  testWidgets('macro card e drill-down com answers em rótulos', (tester) async {
    final sofiaId =
        await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
    await childRepository.setChildResponsibles(
      childId: sofiaId,
      responsibleUids: const ['resp-1'],
      updatedBy: 'u1',
    );

    // Criança não vinculada não aparece.
    await childRepository.createChild(name: 'Pedro', createdBy: 'u1');

    final recordId = await presenceRepository.registerArrival(
      childId: sofiaId,
      dayKey: '2026-11-02',
      arrivedAt: DateTime(2026, 11, 2, 8, 0),
      createdBy: 'u1',
    );
    await presenceRepository.registerAnswer(
      recordId: recordId,
      question: _incidentQuestion(),
      value: 'sim',
      recordedPhase: RecordedPhase.duranteDia,
      createdBy: 'u1',
      recordedAt: DateTime(2026, 11, 2, 10),
    );
    await presenceRepository.registerDeparture(
      recordId: recordId,
      departedAt: DateTime(2026, 11, 2, 17, 0),
      updatedBy: 'u1',
    );

    // Mais um dia para alimentar mediana/rotina.
    final r2 = await presenceRepository.registerArrival(
      childId: sofiaId,
      dayKey: '2026-11-03',
      arrivedAt: DateTime(2026, 11, 3, 8, 5),
      createdBy: 'u1',
    );
    await presenceRepository.registerDeparture(
      recordId: r2,
      departedAt: DateTime(2026, 11, 3, 17, 0),
      updatedBy: 'u1',
    );

    await tester.pumpWidget(
      _wrap(
        RelatoriosScreen(
          responsibleUid: 'resp-1',
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          now: DateTime(2026, 11, 2, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('relatorios-list')), findsOneWidget);
    expect(find.byKey(ValueKey('relatorio-child-$sofiaId')), findsOneWidget);
    expect(find.text('Sofia'), findsOneWidget);
    expect(find.text('Pedro'), findsNothing);
    expect(find.text('Incidente'), findsWidgets);
    expect(find.textContaining('Rotina na semana'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('relatorio-child-$sofiaId')));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('relatorio-detail-$sofiaId')), findsOneWidget);
    final recordFinder = find.byKey(ValueKey('relatorio-record-$recordId'));
    await tester.ensureVisible(recordFinder);
    await tester.pumpAndSettle();
    expect(recordFinder, findsOneWidget);
    expect(find.textContaining('Temperatura elevada?'), findsWidgets);
    expect(find.textContaining('Sim'), findsWidgets);
    // snapshot label, não o option id cru sozinho como valor.
    expect(find.textContaining('Temperatura elevada?: Sim'), findsOneWidget);
  });
}
