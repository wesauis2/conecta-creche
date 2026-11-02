import 'package:conecta_creche/levels/level_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late LevelRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = LevelRepository(firestore: firestore);
  });

  group('createLevel', () {
    test('creates with name, sortIndex and audit', () async {
      final id = await repository.createLevel(
        name: 'Maternal',
        createdBy: 'uid-1',
      );

      final doc = await firestore.collection('levels').doc(id).get();
      final data = doc.data()!;

      expect(data['name'], 'Maternal');
      expect(data['sortIndex'], 0);
      expect(data['active'], isTrue);
      expect(data['createdBy'], 'uid-1');
      expect(data['updatedBy'], 'uid-1');
      expect(data['createdAt'], isNotNull);
    });

    test('assigns incremental sortIndex by default', () async {
      await repository.createLevel(name: 'A', createdBy: 'u1');
      final b = await repository.createLevel(name: 'B', createdBy: 'u1');

      final docB = await firestore.collection('levels').doc(b).get();
      expect(docB.data()!['sortIndex'], 1);
    });
  });

  group('updateLevel', () {
    test('updates name and soft-deactivates', () async {
      final id = await repository.createLevel(
        name: 'Antes',
        createdBy: 'uid-1',
      );

      await repository.updateLevel(
        levelId: id,
        name: 'Depois',
        active: false,
        updatedBy: 'uid-2',
      );

      final doc = await firestore.collection('levels').doc(id).get();
      final data = doc.data()!;
      expect(data['name'], 'Depois');
      expect(data['active'], isFalse);
      expect(data['updatedBy'], 'uid-2');
      expect(doc.exists, isTrue);
    });
  });

  group('watchLevels', () {
    test('returns levels sorted by sortIndex', () async {
      await repository.createLevel(name: 'Z', createdBy: 'u1', sortIndex: 2);
      await repository.createLevel(name: 'A', createdBy: 'u1', sortIndex: 0);

      final list = await repository.watchLevels().first;
      expect(list.map((l) => l.name), ['A', 'Z']);
    });
  });
}
