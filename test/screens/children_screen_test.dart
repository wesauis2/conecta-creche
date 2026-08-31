import 'package:conecta_creche/presence/child_repository.dart';
import 'package:conecta_creche/screens/children_screen.dart';
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
  late ChildRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ChildRepository(firestore: firestore);
  });

  testWidgets('cuidador sees only active children and no inactivate action',
      (tester) async {
    await repository.createChild(name: 'Zeca', createdBy: 'u1');
    final inactiveId =
        await repository.createChild(name: 'Ana', createdBy: 'u1');
    await repository.updateChild(
      childId: inactiveId,
      active: false,
      updatedBy: 'u-gestao',
    );

    await tester.pumpWidget(
      _wrap(
        ChildrenScreen(
          profile: _profile(UserRole.cuidador),
          childRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zeca'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
    expect(find.byIcon(Icons.block_outlined), findsNothing);
    expect(find.byIcon(Icons.restore_outlined), findsNothing);
  });

  testWidgets(
      'gestão sees active and inactive children with inactivate/reactivate',
      (tester) async {
    await repository.createChild(name: 'Zeca', createdBy: 'u1');
    final inactiveId =
        await repository.createChild(name: 'Ana', createdBy: 'u1');
    await repository.updateChild(
      childId: inactiveId,
      active: false,
      updatedBy: 'u-gestao',
    );

    await tester.pumpWidget(
      _wrap(
        ChildrenScreen(
          profile: _profile(UserRole.gestao),
          childRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zeca'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    expect(find.byIcon(Icons.restore_outlined), findsOneWidget);
  });

  testWidgets('gestão can inactivate a child', (tester) async {
    final id = await repository.createChild(name: 'Zeca', createdBy: 'u1');

    await tester.pumpWidget(
      _wrap(
        ChildrenScreen(
          profile: _profile(UserRole.gestao),
          childRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.block_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inativar'));
    await tester.pumpAndSettle();

    final doc = await firestore.collection('children').doc(id).get();
    expect(doc.data()!['active'], isFalse);
  });

  testWidgets('gestão can reactivate a child', (tester) async {
    final id = await repository.createChild(name: 'Ana', createdBy: 'u1');
    await repository.updateChild(
      childId: id,
      active: false,
      updatedBy: 'u-gestao',
    );

    await tester.pumpWidget(
      _wrap(
        ChildrenScreen(
          profile: _profile(UserRole.gestao),
          childRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.restore_outlined));
    await tester.pumpAndSettle();

    final doc = await firestore.collection('children').doc(id).get();
    expect(doc.data()!['active'], isTrue);
  });

  testWidgets('editing a name saves the new value', (tester) async {
    final id = await repository.createChild(name: 'Zeca', createdBy: 'u1');

    await tester.pumpWidget(
      _wrap(
        ChildrenScreen(
          profile: _profile(UserRole.cuidador),
          childRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zeca'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Zeca Silva');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final doc = await firestore.collection('children').doc(id).get();
    expect(doc.data()!['name'], 'Zeca Silva');
  });

  testWidgets('has no delete affordance', (tester) async {
    await repository.createChild(name: 'Zeca', createdBy: 'u1');

    await tester.pumpWidget(
      _wrap(
        ChildrenScreen(
          profile: _profile(UserRole.admin),
          childRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.textContaining('Excluir'), findsNothing);
  });

  testWidgets('blocks access for roles without canOperatePresence',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChildrenScreen(
          profile: _profile(UserRole.responsavel),
          childRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Você não tem permissão para ver esta área.'),
      findsOneWidget,
    );
  });
}
