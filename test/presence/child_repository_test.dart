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
      expect(data['responsibleUids'], <String>[]);
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

    test('sets optional levelId/classId and syncs classes.childIds', () async {
      final childId = await repository.createChild(
        name: 'Ana',
        createdBy: 'uid-1',
      );
      await firestore.collection('classes').doc('cls-1').set({
        'year': 2026,
        'levelIds': <String>[],
        'childIds': <String>[],
        'caregiverUids': <String>[],
        'active': true,
      });

      await repository.updateChild(
        childId: childId,
        levelId: 'lvl-1',
        classId: 'cls-1',
        updatedBy: 'uid-gestao',
      );

      final childDoc = await firestore.collection('children').doc(childId).get();
      expect(childDoc.data()!['levelId'], 'lvl-1');
      expect(childDoc.data()!['classId'], 'cls-1');

      final classDoc = await firestore.collection('classes').doc('cls-1').get();
      expect(classDoc.data()!['childIds'], [childId]);
    });

    test('clears levelId/classId without requiring them for presence catalog',
        () async {
      final childId = await repository.createChild(
        name: 'Beto',
        createdBy: 'uid-1',
      );
      await firestore.collection('classes').doc('cls-1').set({
        'year': 2026,
        'childIds': <String>[childId],
        'active': true,
      });
      await firestore.collection('children').doc(childId).update({
        'levelId': 'lvl-1',
        'classId': 'cls-1',
      });

      await repository.updateChild(
        childId: childId,
        clearLevelId: true,
        clearClassId: true,
        updatedBy: 'uid-gestao',
      );

      final childDoc = await firestore.collection('children').doc(childId).get();
      expect(childDoc.data()!['levelId'], isNull);
      expect(childDoc.data()!['classId'], isNull);

      final active = await repository.listActiveChildren();
      expect(active.single.id, childId);
      expect(active.single.levelId, isNull);
      expect(active.single.classId, isNull);
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

  group('watchChildren', () {
    test('emits all children (active and inactive) sorted by name', () async {
      await repository.createChild(name: 'Zeca', createdBy: 'uid-1');
      final inactiveId =
          await repository.createChild(name: 'Ana', createdBy: 'uid-1');
      await repository.createChild(name: 'Bruno', createdBy: 'uid-1');
      await repository.updateChild(
        childId: inactiveId,
        active: false,
        updatedBy: 'uid-gestao',
      );

      final children = await repository.watchChildren().first;

      expect(children.map((c) => c.name), ['Ana', 'Bruno', 'Zeca']);
      expect(children.firstWhere((c) => c.name == 'Ana').active, isFalse);
    });

    test('emits activeOnly: true excluding inactive children', () async {
      await repository.createChild(name: 'Zeca', createdBy: 'uid-1');
      final inactiveId =
          await repository.createChild(name: 'Ana', createdBy: 'uid-1');
      await repository.updateChild(
        childId: inactiveId,
        active: false,
        updatedBy: 'uid-gestao',
      );

      final children =
          await repository.watchChildren(activeOnly: true).first;

      expect(children.map((c) => c.name), ['Zeca']);
    });

    test('emits updates when a child changes', () async {
      final id = await repository.createChild(name: 'Ana', createdBy: 'u1');

      final emissions = <List<String>>[];
      final subscription = repository.watchChildren().listen((children) {
        emissions.add(children.map((c) => c.name).toList());
      });

      await Future<void>.delayed(Duration.zero);
      await repository.updateChild(
        childId: id,
        name: 'Ana Maria',
        updatedBy: 'u1',
      );
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, ['Ana Maria']);
      await subscription.cancel();
    });
  });

  group('responsible links', () {
    test('setChildResponsibles replaces responsibleUids and stamps audit',
        () async {
      final id = await repository.createChild(name: 'Ana', createdBy: 'u1');

      await repository.setChildResponsibles(
        childId: id,
        responsibleUids: ['resp-a', 'resp-b'],
        updatedBy: 'uid-gestao',
      );

      final doc = await firestore.collection('children').doc(id).get();
      final data = doc.data()!;
      expect(data['responsibleUids'], ['resp-a', 'resp-b']);
      expect(data['updatedBy'], 'uid-gestao');

      await repository.setChildResponsibles(
        childId: id,
        responsibleUids: ['resp-b'],
        updatedBy: 'uid-gestao',
      );

      final updated = await firestore.collection('children').doc(id).get();
      expect(updated.data()!['responsibleUids'], ['resp-b']);
    });

    test('listChildrenForResponsible queries by array-contains uid', () async {
      final ana = await repository.createChild(name: 'Ana', createdBy: 'u1');
      final beto = await repository.createChild(name: 'Beto', createdBy: 'u1');
      await repository.createChild(name: 'Caio', createdBy: 'u1');

      await repository.setChildResponsibles(
        childId: ana,
        responsibleUids: ['resp-1', 'resp-2'],
        updatedBy: 'gestao',
      );
      await repository.setChildResponsibles(
        childId: beto,
        responsibleUids: ['resp-1'],
        updatedBy: 'gestao',
      );

      final forResp1 = await repository.listChildrenForResponsible('resp-1');
      final forResp2 = await repository.listChildrenForResponsible('resp-2');
      final forOther = await repository.listChildrenForResponsible('resp-x');

      expect(forResp1.map((c) => c.name), ['Ana', 'Beto']);
      expect(forResp2.map((c) => c.name), ['Ana']);
      expect(forOther, isEmpty);
    });

    test('setResponsibleActiveChildren adds/removes across children', () async {
      final ana = await repository.createChild(name: 'Ana', createdBy: 'u1');
      final beto = await repository.createChild(name: 'Beto', createdBy: 'u1');
      final caio = await repository.createChild(name: 'Caio', createdBy: 'u1');

      await repository.setResponsibleActiveChildren(
        uid: 'resp-1',
        activeChildIds: [ana, beto],
        updatedBy: 'gestao',
      );

      expect(
        (await repository.listChildrenForResponsible('resp-1')).map((c) => c.id),
        containsAll([ana, beto]),
      );

      await repository.setResponsibleActiveChildren(
        uid: 'resp-1',
        activeChildIds: [beto, caio],
        updatedBy: 'gestao',
      );

      final linked =
          await repository.listChildrenForResponsible('resp-1');
      expect(linked.map((c) => c.id).toSet(), {beto, caio});
    });

    test('setResponsibleActiveChildren keeps inactive linked children',
        () async {
      final ativa = await repository.createChild(name: 'Ana', createdBy: 'u1');
      final inativa =
          await repository.createChild(name: 'Beto', createdBy: 'u1');
      await repository.setChildResponsibles(
        childId: ativa,
        responsibleUids: ['resp-1'],
        updatedBy: 'gestao',
      );
      await repository.setChildResponsibles(
        childId: inativa,
        responsibleUids: ['resp-1'],
        updatedBy: 'gestao',
      );
      await repository.updateChild(
        childId: inativa,
        active: false,
        updatedBy: 'gestao',
      );

      await repository.setResponsibleActiveChildren(
        uid: 'resp-1',
        activeChildIds: <String>[],
        updatedBy: 'gestao',
      );

      final linked =
          await repository.listChildrenForResponsible('resp-1');
      expect(linked.map((c) => c.id), [inativa]);
      expect(linked.single.active, isFalse);
    });

    test('removing a link does not delete presence records', () async {
      final childId =
          await repository.createChild(name: 'Ana', createdBy: 'u1');
      await repository.setChildResponsibles(
        childId: childId,
        responsibleUids: ['resp-1'],
        updatedBy: 'gestao',
      );
      await firestore.collection('presence_records').add({
        'childId': childId,
        'dayKey': '2026-11-02',
        'isOpen': true,
        'arrivedAt': DateTime.utc(2026, 11, 2, 12),
        'createdBy': 'cuidador',
      });

      await repository.setChildResponsibles(
        childId: childId,
        responsibleUids: <String>[],
        updatedBy: 'gestao',
      );

      final presence = await firestore.collection('presence_records').get();
      expect(presence.docs, hasLength(1));
      expect(presence.docs.single.data()['childId'], childId);

      final child = await firestore.collection('children').doc(childId).get();
      expect(child.data()!['responsibleUids'], <String>[]);
    });
  });
}
