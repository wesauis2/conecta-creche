import 'package:conecta_creche/presence/child_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ChildRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ChildRepository(firestore: firestore);
  });

  group('createChild', () {
    test('creates an active child with audit fields', () async {
      final id = await repository.createChild(
        name: 'Ana',
        createdBy: 'uid-1',
      );

      final doc = await firestore.collection('children').doc(id).get();
      final data = doc.data()!;

      expect(data['name'], 'Ana');
      expect(data['active'], isTrue);
      expect(data['createdBy'], 'uid-1');
      expect(data['updatedBy'], 'uid-1');
      expect(data['createdAt'], isNotNull);
      expect(data['updatedAt'], isNotNull);
    });
  });

  group('updateChild', () {
    test('updates name and stamps updatedBy/updatedAt', () async {
      final id = await repository.createChild(
        name: 'Ana',
        createdBy: 'uid-1',
      );

      await repository.updateChild(
        childId: id,
        name: 'Ana Maria',
        updatedBy: 'uid-2',
      );

      final doc = await firestore.collection('children').doc(id).get();
      final data = doc.data()!;

      expect(data['name'], 'Ana Maria');
      expect(data['active'], isTrue);
      expect(data['updatedBy'], 'uid-2');
    });

    test('inactivates a child without touching its name', () async {
      final id = await repository.createChild(
        name: 'Beto',
        createdBy: 'uid-1',
      );

      await repository.updateChild(
        childId: id,
        active: false,
        updatedBy: 'uid-gestao',
      );

      final doc = await firestore.collection('children').doc(id).get();
      final data = doc.data()!;

      expect(data['name'], 'Beto');
      expect(data['active'], isFalse);
    });
  });

  group('listActiveChildren', () {
    test('returns only active children, sorted by name', () async {
      await repository.createChild(name: 'Zeca', createdBy: 'uid-1');
      final inactiveId =
          await repository.createChild(name: 'Ana', createdBy: 'uid-1');
      await repository.createChild(name: 'Bruno', createdBy: 'uid-1');
      await repository.updateChild(
        childId: inactiveId,
        active: false,
        updatedBy: 'uid-gestao',
      );

      final active = await repository.listActiveChildren();

      expect(active.map((c) => c.name), ['Bruno', 'Zeca']);
      expect(active.every((c) => c.active), isTrue);
    });
  });
}
