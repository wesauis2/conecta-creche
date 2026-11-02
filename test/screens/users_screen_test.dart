import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/screens/users_screen.dart';
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

Future<void> _seedUser(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required UserRole role,
  String? displayName,
  String? email,
}) async {
  await firestore.collection('users').doc(uid).set({
    'uid': uid,
    'displayName': displayName ?? uid,
    'email': email ?? '$uid@example.com',
  });
  await firestore.collection('user_roles').doc(uid).set({
    'role': role.name,
  });
}

void main() {
  late FakeFirebaseFirestore firestore;
  late ChildRepository childRepository;
  late UserRepository userRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    childRepository = ChildRepository(firestore: firestore);
    userRepository = UserRepository(firestore: firestore);
  });

  testWidgets('gestão can link active children to a responsável',
      (tester) async {
    await _seedUser(
      firestore,
      uid: 'resp-1',
      role: UserRole.responsavel,
      displayName: 'Maria Responsável',
    );
    final ana =
        await childRepository.createChild(name: 'Ana', createdBy: 'u1');
    final beto =
        await childRepository.createChild(name: 'Beto', createdBy: 'u1');

    await tester.pumpWidget(
      _wrap(
        UsersScreen(
          profile: _profile(UserRole.gestao),
          userRepository: userRepository,
          childRepository: childRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Responsável'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Responsável'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();

    expect(find.text('Crianças de Maria Responsável'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final linked =
        await childRepository.listChildrenForResponsible('resp-1');
    expect(linked.map((c) => c.id), [ana]);
    expect(linked.map((c) => c.id), isNot(contains(beto)));
  });

  testWidgets('link icon is only shown for responsáveis', (tester) async {
    await _seedUser(
      firestore,
      uid: 'cuid-1',
      role: UserRole.cuidador,
      displayName: 'João Cuidador',
    );

    await tester.pumpWidget(
      _wrap(
        UsersScreen(
          profile: _profile(UserRole.gestao),
          userRepository: userRepository,
          childRepository: childRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cuidador'));
    await tester.pumpAndSettle();

    expect(find.text('João Cuidador'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsNothing);
  });
}
