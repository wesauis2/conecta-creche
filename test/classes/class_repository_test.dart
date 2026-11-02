import 'package:conecta_creche/classes/class_repository.dart';
import 'package:conecta_creche/presence/child_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ClassRepository repository;
  late ChildRepository childRepository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ClassRepository(firestore: firestore);
    childRepository = ChildRepository(firestore: firestore);
  });

  group('createClass', () {
    test('creates turma with room text and syncs child classId', () async {
      final childId = await childRepository.createChild(
        name: 'Ana',
        createdBy: 'u1',
      );

      final id = await repository.createClass(
        year: 2026,
        levelIds: const ['lvl-1'],
        room: 'Sala B',
        caregiverUids: const ['care-1'],
        childIds: [childId],
        createdBy: 'uid-gestao',
      );

      final doc = await firestore.collection('classes').doc(id).get();
      final data = doc.data()!;
      expect(data['year'], 2026);
      expect(data['levelIds'], ['lvl-1']);
      expect(data['room'], 'Sala B');
      expect(data['caregiverUids'], ['care-1']);
      expect(data['childIds'], [childId]);
      expect(data['active'], isTrue);

      final childDoc = await firestore.collection('children').doc(childId).get();
      expect(childDoc.data()!['classId'], id);
    });
  });

  group('updateClass', () {
    test('syncs childIds add/remove onto children.classId', () async {
      final a = await childRepository.createChild(name: 'Ana', createdBy: 'u1');
      final b = await childRepository.createChild(name: 'Beto', createdBy: 'u1');

      final classId = await repository.createClass(
        year: 2026,
        childIds: [a],
        createdBy: 'uid-gestao',
      );

      await repository.updateClass(
        classId: classId,
        childIds: [b],
        updatedBy: 'uid-gestao',
      );

      final classDoc = await firestore.collection('classes').doc(classId).get();
      expect(classDoc.data()!['childIds'], [b]);

      final docA = await firestore.collection('children').doc(a).get();
      final docB = await firestore.collection('children').doc(b).get();
      expect(docA.data()!['classId'], isNull);
      expect(docB.data()!['classId'], classId);
    });

    test('clears optional room', () async {
      final id = await repository.createClass(
        year: 2026,
        room: 'Sala A',
        createdBy: 'u1',
      );

      await repository.updateClass(
        classId: id,
        clearRoom: true,
        updatedBy: 'u2',
      );

      final doc = await firestore.collection('classes').doc(id).get();
      expect(doc.data()!['room'], isNull);
    });
  });
}
