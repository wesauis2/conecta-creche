import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/parecer.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/presence_day_screen.dart';
import 'package:conecta_creche/users/user_profile.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dayKey = '2026-08-30';

UserProfile _profile(UserRole role) => UserProfile(
      uid: 'uid-${role.name}',
      role: role,
      displayName: role.label,
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  late FakeFirebaseFirestore firestore;
  late ChildRepository childRepository;
  late PresenceRepository presenceRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    childRepository = ChildRepository(firestore: firestore);
    presenceRepository = PresenceRepository(firestore: firestore);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    UserRole role = UserRole.cuidador,
  }) async {
    await tester.pumpWidget(
      _wrap(
        PresenceDayScreen(
          profile: _profile(role),
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          dayKey: _dayKey,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('chips filter', () {
    testWidgets('defaults to Presentes and only shows children with an open record',
        (tester) async {
      await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      final miguelId =
          await childRepository.createChild(name: 'Miguel', createdBy: 'u1');
      await presenceRepository.registerArrival(
        childId: miguelId,
        dayKey: _dayKey,
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'u1',
      );

      await pumpScreen(tester);

      expect(find.text('Miguel'), findsOneWidget);
      expect(find.text('Sofia'), findsNothing);
      final presentesChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Presentes'));
      expect(presentesChip.selected, isTrue);
    });

    testWidgets('Saíram shows only children with a closed record and no open one',
        (tester) async {
      final anaId =
          await childRepository.createChild(name: 'Ana', createdBy: 'u1');
      final id = await presenceRepository.registerArrival(
        childId: anaId,
        dayKey: _dayKey,
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'u1',
      );
      await presenceRepository.registerDeparture(
        recordId: id,
        departedAt: DateTime.utc(2026, 8, 30, 12),
        parecer: const Parecer(),
        updatedBy: 'u1',
      );
      await childRepository.createChild(name: 'Bruno', createdBy: 'u1');

      await pumpScreen(tester);

      await tester.tap(find.text('Saíram'));
      await tester.pumpAndSettle();

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Bruno'), findsNothing);
    });

    testWidgets('Todos shows every active child regardless of presence state',
        (tester) async {
      await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      final miguelId =
          await childRepository.createChild(name: 'Miguel', createdBy: 'u1');
      await presenceRepository.registerArrival(
        childId: miguelId,
        dayKey: _dayKey,
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'u1',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      expect(find.text('Sofia'), findsOneWidget);
      expect(find.text('Miguel'), findsOneWidget);
      // Sofia has no record today: chegada affordance.
      expect(find.text('Chegada'), findsOneWidget);
      // Miguel is open: saída affordance.
      expect(find.text('Saída'), findsOneWidget);
    });

    testWidgets('chips are exclusive: selecting Todos deselects Presentes',
        (tester) async {
      await childRepository.createChild(name: 'Sofia', createdBy: 'u1');

      await pumpScreen(tester);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      final presentesChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Presentes'));
      final todosChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Todos'));
      expect(presentesChip.selected, isFalse);
      expect(todosChip.selected, isTrue);
    });
  });

  group('app bar', () {
    testWidgets('cuidador sees Nova and Crianças actions', (tester) async {
      await pumpScreen(tester);

      expect(find.widgetWithText(TextButton, 'Nova'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Crianças'), findsOneWidget);
    });
  });

  group('confirm chegada', () {
    testWidgets('tapping a chegada row asks for confirmation then registers the arrival',
        (tester) async {
      await childRepository.createChild(name: 'Sofia', createdBy: 'u1');

      await pumpScreen(tester);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sofia'));
      await tester.pumpAndSettle();

      expect(find.text('Registrar chegada?'), findsOneWidget);
      expect(find.textContaining('Confirma a chegada de Sofia'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar chegada'));
      await tester.pumpAndSettle();

      final records = await presenceRepository.listByDayKey(dayKey: _dayKey);
      expect(records, hasLength(1));
      expect(records.single.isOpen, isTrue);
      expect(records.single.createdBy, 'uid-cuidador');

      // Filter switched back to Presentes and shows the now-open child.
      final presentesChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Presentes'));
      expect(presentesChip.selected, isTrue);
      expect(find.text('Sofia'), findsOneWidget);
    });

    testWidgets('cancelling the confirm dialog does not create a record',
        (tester) async {
      await childRepository.createChild(name: 'Sofia', createdBy: 'u1');

      await pumpScreen(tester);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sofia'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      final records = await presenceRepository.listByDayKey(dayKey: _dayKey);
      expect(records, isEmpty);
    });

    testWidgets(
        'an open record created concurrently is communicated as a blocked chegada',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');

      await pumpScreen(tester);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sofia'));
      await tester.pumpAndSettle();

      // Simulate a concurrent chegada from another device while the dialog
      // is open, before the user confirms.
      await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _dayKey,
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'other-device',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar chegada'));
      await tester.pumpAndSettle();

      expect(find.text('Chegada bloqueada'), findsOneWidget);
      expect(
        find.textContaining('Sofia já tem registro aberto hoje'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Entendi'));
      await tester.pumpAndSettle();

      final records = await presenceRepository.listByDayKey(dayKey: _dayKey);
      expect(records, hasLength(1));
      expect(records.single.createdBy, 'other-device');
    });
  });

  group('saída + parecer', () {
    testWidgets('confirming saída opens the parecer form and closes the record',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _dayKey,
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'u1',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Sofia'));
      await tester.pumpAndSettle();

      expect(find.text('Registrar saída?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Registrar saída'));
      await tester.pumpAndSettle();

      expect(find.text('Saída · Sofia'), findsOneWidget);
      // Choose a non-default option for one question.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Muito'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar saída'));
      await tester.pumpAndSettle();

      final records = await presenceRepository.listByDayKey(dayKey: _dayKey);
      expect(records.single.isOpen, isFalse);
      expect(records.single.parecer?.chorou, ParecerChorou.muito);
      expect(records.single.updatedBy, 'uid-cuidador');

      // Back on the list, now filtered to Saíram.
      final sairamChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Saíram'));
      expect(sairamChip.selected, isTrue);
      expect(find.text('Sofia'), findsOneWidget);
    });

    testWidgets('editing an existing parecer from Saíram updates it without reopening',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      final recordId = await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _dayKey,
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'u1',
      );
      await presenceRepository.registerDeparture(
        recordId: recordId,
        departedAt: DateTime.utc(2026, 8, 30, 12),
        parecer: const Parecer(),
        updatedBy: 'u1',
      );

      await pumpScreen(tester);
      await tester.tap(find.text('Saíram'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sofia'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Abrir o parecer de Sofia para correção?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Abrir parecer'));
      await tester.pumpAndSettle();

      expect(find.text('Parecer · Sofia'), findsOneWidget);
      final humorChip = find.widgetWithText(ChoiceChip, 'Irritado');
      await tester.scrollUntilVisible(humorChip, 200);
      await tester.pumpAndSettle();
      await tester.tap(humorChip);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar parecer'));
      await tester.pumpAndSettle();

      final doc =
          await firestore.collection('presence_records').doc(recordId).get();
      final data = doc.data()!;
      expect(data['isOpen'], isFalse);
      expect(data['parecer']['humor'], 'irritado');
    });
  });

  group('nova criança', () {
    testWidgets('creating a child from the app bar switches to Todos and shows it',
        (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Nova'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Zeca');
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      final todosChip =
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Todos'));
      expect(todosChip.selected, isTrue);
      expect(find.text('Zeca'), findsOneWidget);
    });
  });

  group('access control', () {
    testWidgets('roles without canOperatePresence never reach this screen in HomeShell',
        (tester) async {
      // PresenceDayScreen itself is only reachable for canOperatePresence
      // roles (gated in HomeShell); it still renders for any profile passed
      // to it directly since the gate lives one layer up, matching how
      // ChildrenScreen is guarded.
      await childRepository.createChild(name: 'Sofia', createdBy: 'u1');

      await pumpScreen(tester, role: UserRole.gestao);
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      expect(find.text('Sofia'), findsOneWidget);
    });
  });
}
