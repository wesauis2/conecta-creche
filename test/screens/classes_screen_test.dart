import 'package:conecta_creche/classes/class_repository.dart';
import 'package:conecta_creche/levels/level_repository.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/screens/classes_screen.dart';
import 'package:conecta_creche/users/user_profile.dart';
import 'package:conecta_creche/users/user_repository.dart';
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
  late ClassRepository classRepository;
  late LevelRepository levelRepository;
  late ChildRepository childRepository;
  late UserRepository userRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    classRepository = ClassRepository(firestore: firestore);
    levelRepository = LevelRepository(firestore: firestore);
    childRepository = ChildRepository(firestore: firestore);
    userRepository = UserRepository(firestore: firestore);
  });

  testWidgets('blocks access below gestão', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ClassesScreen(
          profile: _profile(UserRole.cuidador),
          classRepository: classRepository,
          levelRepository: levelRepository,
          childRepository: childRepository,
          userRepository: userRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Você não tem permissão para gerenciar turmas.'),
      findsOneWidget,
    );
  });

  testWidgets('gestão lists turmas and opens create dialog', (tester) async {
    await classRepository.createClass(
      year: 2026,
      room: 'Sala A',
      createdBy: 'u1',
    );

    await tester.pumpWidget(
      _wrap(
        ClassesScreen(
          profile: _profile(UserRole.gestao),
          classRepository: classRepository,
          levelRepository: levelRepository,
          childRepository: childRepository,
          userRepository: userRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026 · Sala A'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Nova turma'), findsOneWidget);
    expect(find.text('Sala (opcional)'), findsOneWidget);
  });
}
