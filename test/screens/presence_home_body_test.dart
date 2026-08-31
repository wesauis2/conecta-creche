import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:conecta_creche/screens/presence_home_body.dart';
import 'package:conecta_creche/users/user_profile.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers ticket 07's role routing: gestão/admin → agregado, cuidador →
/// dia, responsável/convidado → placeholder (no presence entry point). Only
/// needs [profile] and the presence repos, so it exercises the same routing
/// `HomeShell` delegates to without touching `GoogleAuthService`.
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

  Future<void> pumpBody(
    WidgetTester tester, {
    required UserRole role,
    List<Widget> appBarActions = const [],
  }) async {
    await tester.pumpWidget(
      _wrap(
        PresenceHomeBody(
          profile: _profile(role),
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          appBarActions: appBarActions,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('role routing', () {
    testWidgets('admin lands on the aggregate gestão view', (tester) async {
      await pumpBody(tester, role: UserRole.admin);

      expect(find.byKey(const ValueKey('gestao-week-grid')), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Nova'), findsNothing);
    });

    testWidgets('gestão lands on the aggregate gestão view', (tester) async {
      await pumpBody(tester, role: UserRole.gestao);

      expect(find.byKey(const ValueKey('gestao-week-grid')), findsOneWidget);
    });

    testWidgets('cuidador lands on the day view', (tester) async {
      await pumpBody(tester, role: UserRole.cuidador);

      expect(find.widgetWithText(TextButton, 'Nova'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Crianças'), findsOneWidget);
      expect(find.byKey(const ValueKey('gestao-week-grid')), findsNothing);
    });

    testWidgets(
        'responsável does not reach any presence surface, only the placeholder',
        (tester) async {
      await pumpBody(tester, role: UserRole.responsavel);

      expect(
        find.textContaining('Em breve você poderá acompanhar'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gestao-week-grid')), findsNothing);
      expect(find.widgetWithText(TextButton, 'Nova'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Crianças'), findsNothing);
    });

    testWidgets(
        'convidado does not reach any presence surface, only the placeholder',
        (tester) async {
      await pumpBody(tester, role: UserRole.convidado);

      expect(
        find.textContaining('Em breve você poderá acompanhar'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gestao-week-grid')), findsNothing);
      expect(find.widgetWithText(TextButton, 'Nova'), findsNothing);
    });
  });

  group('app bar actions', () {
    testWidgets('forwards appBarActions onto the gestão screen',
        (tester) async {
      await pumpBody(
        tester,
        role: UserRole.gestao,
        appBarActions: const [
          IconButton(
            key: ValueKey('probe-action'),
            onPressed: null,
            icon: Icon(Icons.person_outline),
          ),
        ],
      );

      expect(find.byKey(const ValueKey('probe-action')), findsOneWidget);
    });

    testWidgets('forwards appBarActions onto the cuidador day screen',
        (tester) async {
      await pumpBody(
        tester,
        role: UserRole.cuidador,
        appBarActions: const [
          IconButton(
            key: ValueKey('probe-action'),
            onPressed: null,
            icon: Icon(Icons.person_outline),
          ),
        ],
      );

      expect(find.byKey(const ValueKey('probe-action')), findsOneWidget);
    });

    testWidgets('forwards appBarActions onto the placeholder',
        (tester) async {
      await pumpBody(
        tester,
        role: UserRole.responsavel,
        appBarActions: const [
          IconButton(
            key: ValueKey('probe-action'),
            onPressed: null,
            icon: Icon(Icons.person_outline),
          ),
        ],
      );

      expect(find.byKey(const ValueKey('probe-action')), findsOneWidget);
    });
  });
}
