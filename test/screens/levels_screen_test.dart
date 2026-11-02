import 'package:conecta_creche/levels/level_repository.dart';
import 'package:conecta_creche/screens/levels_screen.dart';
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
  late LevelRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = LevelRepository(firestore: firestore);
  });

  testWidgets('blocks access below gestão', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LevelsScreen(
          profile: _profile(UserRole.cuidador),
          levelRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Você não tem permissão para gerenciar níveis.'),
      findsOneWidget,
    );
  });

  testWidgets('gestão can create a level via dialog', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LevelsScreen(
          profile: _profile(UserRole.gestao),
          levelRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Berçário');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Berçário'), findsOneWidget);
  });
}
