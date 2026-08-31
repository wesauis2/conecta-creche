import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/parecer.dart';
import 'package:conecta_creche/presence/presence_clock.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/presence_gestao_screen.dart';
import 'package:conecta_creche/users/user_profile.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

// 2026-09-01 is a Tuesday; the Dom→Sáb week containing it runs from
// 2026-08-30 (Sun) to 2026-09-05 (Sat). Built directly as a São Paulo
// TZDateTime (like PresenceClock.dayKeyFor's own tests) so the test is
// immune to the host machine's local timezone.
tz.TZDateTime _spNoon(int year, int month, int day) {
  PresenceClock.ensureInitialized();
  return tz.TZDateTime(PresenceClock.saoPauloLocation, year, month, day, 12);
}

final _anchorDate = _spNoon(2026, 9, 1);
const _selectedDayKey = '2026-09-01';

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
    UserRole role = UserRole.gestao,
  }) async {
    await tester.pumpWidget(
      _wrap(
        PresenceGestaoScreen(
          profile: _profile(role),
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          initialDate: _anchorDate,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('calendar week', () {
    testWidgets('week starts on Sunday (Dom→Sáb, one row)', (tester) async {
      await pumpScreen(tester);

      // Anchored on Tue 2026-09-01: the Dom→Sáb week is 30 ago .. 5 set.
      final sunday = find.byKey(const ValueKey('gestao-day-2026-08-30'));
      final tuesdayAnchor = find.byKey(const ValueKey('gestao-day-2026-09-01'));
      final saturday = find.byKey(const ValueKey('gestao-day-2026-09-05'));

      expect(sunday, findsOneWidget);
      expect(tuesdayAnchor, findsOneWidget);
      expect(saturday, findsOneWidget);

      // Sunday must render left-most, Saturday right-most: a single row,
      // Dom→Sáb order (never a Monday-first week).
      final sundayX = tester.getTopLeft(sunday).dx;
      final tuesdayX = tester.getTopLeft(tuesdayAnchor).dx;
      final saturdayX = tester.getTopLeft(saturday).dx;
      expect(sundayX, lessThan(tuesdayX));
      expect(tuesdayX, lessThan(saturdayX));

      // Exactly 7 days in the row (one week, one line).
      expect(find.byKey(const ValueKey('gestao-week-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('gestao-month-grid')), findsNothing);
    });

    testWidgets('‹ › shift the week by 7 days', (tester) async {
      await pumpScreen(tester);

      expect(find.text('30 ago – 5 set'), findsOneWidget);

      await tester.tap(find.byTooltip('Próximo'));
      await tester.pumpAndSettle();

      expect(find.text('6 – 12 set'), findsOneWidget);
      // The previously selected day (2026-09-01) is no longer in view.
      expect(find.byKey(const ValueKey('gestao-day-2026-09-01')), findsNothing);

      await tester.tap(find.byTooltip('Anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Anterior'));
      await tester.pumpAndSettle();

      expect(find.text('23 – 29 ago'), findsOneWidget);
    });
  });

  group('calendar month', () {
    testWidgets('Mês tab shows a compact Dom→Sáb grid', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Mês'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('gestao-month-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('gestao-week-grid')), findsNothing);
      expect(find.text('Setembro 2026'), findsOneWidget);
      // Every day of September must be present.
      expect(find.byKey(const ValueKey('gestao-day-2026-09-30')), findsOneWidget);
    });

    testWidgets('deepens to week without any textual gesture hint',
        (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('Mês'));
      await tester.pumpAndSettle();

      // No instructional copy about gestures anywhere in the tree.
      expect(find.textContaining('arraste', findRichText: true), findsNothing);
      expect(find.textContaining('gesto', findRichText: true), findsNothing);
      expect(find.textContaining('swipe', findRichText: true), findsNothing);

      await tester.fling(
        find.byKey(const ValueKey('gestao-month-grid')),
        const Offset(0, -300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('gestao-week-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('gestao-month-grid')), findsNothing);
    });
  });

  group('embedded day list', () {
    testWidgets('has no "Presença" title inside the embedded area, only the app bar',
        (tester) async {
      await pumpScreen(tester);

      // Exactly one "Presença" text: the outer app bar title.
      expect(find.text('Presença'), findsOneWidget);
    });

    testWidgets('no filter selected shows both Presentes and Saíram (multi, none = both)',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      final miguelId =
          await childRepository.createChild(name: 'Miguel', createdBy: 'u1');
      await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _selectedDayKey,
        arrivedAt: DateTime.utc(2026, 9, 1, 12),
        createdBy: 'u1',
      );
      final miguelRecordId = await presenceRepository.registerArrival(
        childId: miguelId,
        dayKey: _selectedDayKey,
        arrivedAt: DateTime.utc(2026, 9, 1, 11),
        createdBy: 'u1',
      );
      await presenceRepository.registerDeparture(
        recordId: miguelRecordId,
        departedAt: DateTime.utc(2026, 9, 1, 16),
        parecer: const Parecer(),
        updatedBy: 'u1',
      );

      await pumpScreen(tester);

      expect(find.text('Sofia'), findsOneWidget);
      expect(find.text('Miguel'), findsOneWidget);

      // Select only "Presentes": only the open child remains.
      await tester.tap(find.widgetWithText(FilterChip, 'Presentes'));
      await tester.pumpAndSettle();
      expect(find.text('Sofia'), findsOneWidget);
      expect(find.text('Miguel'), findsNothing);

      // Also select "Saíram": both are shown again.
      await tester.tap(find.widgetWithText(FilterChip, 'Saíram'));
      await tester.pumpAndSettle();
      expect(find.text('Sofia'), findsOneWidget);
      expect(find.text('Miguel'), findsOneWidget);

      // Deselect "Presentes": only the closed child remains.
      await tester.tap(find.widgetWithText(FilterChip, 'Presentes'));
      await tester.pumpAndSettle();
      expect(find.text('Sofia'), findsNothing);
      expect(find.text('Miguel'), findsOneWidget);
    });

    testWidgets(
        'filter-aware empty message: only Saíram selected but the only '
        'record is still open',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _selectedDayKey,
        arrivedAt: DateTime.utc(2026, 9, 1, 8),
        createdBy: 'u1',
      );

      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Saíram'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma criança saiu neste dia.'), findsOneWidget);
      expect(find.text('Sofia'), findsNothing);
    });

    testWidgets(
        'filter-aware empty message: only Presentes selected but the only '
        'record is already closed',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      final recordId = await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _selectedDayKey,
        arrivedAt: DateTime.utc(2026, 9, 1, 8),
        createdBy: 'u1',
      );
      await presenceRepository.registerDeparture(
        recordId: recordId,
        departedAt: DateTime.utc(2026, 9, 1, 12),
        parecer: const Parecer(),
        updatedBy: 'u1',
      );

      await pumpScreen(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Presentes'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma criança presente neste dia.'), findsOneWidget);
      expect(find.text('Sofia'), findsNothing);
    });

    testWidgets('shows a warning banner when the day has open records',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _selectedDayKey,
        arrivedAt: DateTime.utc(2026, 9, 1, 12),
        createdBy: 'u1',
      );

      await pumpScreen(tester);

      expect(find.textContaining('registro'), findsOneWidget);
      expect(find.textContaining('aberto'), findsOneWidget);
    });

    testWidgets('shows no warning banner when the day has no open records',
        (tester) async {
      final sofiaId =
          await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      final recordId = await presenceRepository.registerArrival(
        childId: sofiaId,
        dayKey: _selectedDayKey,
        arrivedAt: DateTime.utc(2026, 9, 1, 8),
        createdBy: 'u1',
      );
      await presenceRepository.registerDeparture(
        recordId: recordId,
        departedAt: DateTime.utc(2026, 9, 1, 12),
        parecer: const Parecer(),
        updatedBy: 'u1',
      );

      await pumpScreen(tester);

      expect(find.textContaining('aberto'), findsNothing);
    });

    testWidgets('selecting another day swaps the embedded list',
        (tester) async {
      await childRepository.createChild(name: 'Sofia', createdBy: 'u1');
      final laraId =
          await childRepository.createChild(name: 'Lara', createdBy: 'u1');
      await presenceRepository.registerArrival(
        childId: laraId,
        dayKey: '2026-08-31',
        arrivedAt: DateTime.utc(2026, 8, 31, 8),
        createdBy: 'u1',
      );

      await pumpScreen(tester);
      expect(find.text('Sem registros neste dia.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('gestao-day-2026-08-31')));
      await tester.pumpAndSettle();

      expect(find.text('Lara'), findsOneWidget);
    });
  });
}
