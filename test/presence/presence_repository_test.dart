import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/presence/parecer.dart';
import 'package:conecta_creche/presence/presence_open_guard.dart';
import 'package:conecta_creche/presence/presence_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PresenceRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = PresenceRepository(firestore: firestore);
  });

  group('registerArrival', () {
    test('creates an open record with departedAt: null', () async {
      final id = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'uid-1',
      );

      final doc =
          await firestore.collection('presence_records').doc(id).get();
      final data = doc.data()!;

      expect(data['childId'], 'child-1');
      expect(data['dayKey'], '2026-08-30');
      expect(data['isOpen'], isTrue);
      expect(data['departedAt'], isNull);
      expect(data.containsKey('departedAt'), isTrue);
      expect(data['createdBy'], 'uid-1');
    });

    test('a second arrival on the same childId+dayKey while open is blocked', () async {
      await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'uid-1',
      );

      expect(
        () => repository.registerArrival(
          childId: 'child-1',
          dayKey: '2026-08-30',
          arrivedAt: DateTime.utc(2026, 8, 30, 13),
          createdBy: 'uid-1',
        ),
        throwsA(isA<OpenPresenceRecordException>()),
      );
    });

    test('a different child is not blocked by another child\'s open record', () async {
      await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'uid-1',
      );

      final secondId = await repository.registerArrival(
        childId: 'child-2',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 12, 30),
        createdBy: 'uid-1',
      );

      expect(secondId, isNotEmpty);
    });

    test('a new arrival is allowed same-day after the previous record closed', () async {
      final firstId = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );

      await repository.registerDeparture(
        recordId: firstId,
        departedAt: DateTime.utc(2026, 8, 30, 12),
        parecer: const Parecer(),
        updatedBy: 'uid-1',
      );

      final secondId = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 14),
        createdBy: 'uid-1',
      );

      expect(secondId, isNot(firstId));
    });

    test('a new arrival is allowed on the next civil day even if yesterday stayed open', () async {
      await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-29',
        arrivedAt: DateTime.utc(2026, 8, 29, 20),
        createdBy: 'uid-1',
      );

      final todayId = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );

      expect(todayId, isNotEmpty);
    });
  });

  group('registerDeparture', () {
    test('closes the record with departedAt, isOpen: false and the parecer', () async {
      final id = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );

      await repository.registerDeparture(
        recordId: id,
        departedAt: DateTime.utc(2026, 8, 30, 17),
        parecer: const Parecer(humor: ParecerHumor.irritado),
        updatedBy: 'uid-2',
      );

      final doc =
          await firestore.collection('presence_records').doc(id).get();
      final data = doc.data()!;

      expect(data['isOpen'], isFalse);
      expect(data['departedAt'], isNotNull);
      expect(data['parecer']['humor'], 'irritado');
      expect(data['updatedBy'], 'uid-2');
      // Immutable fields untouched.
      expect(data['childId'], 'child-1');
      expect(data['dayKey'], '2026-08-30');
    });
  });

  group('listByDayKey', () {
    test('lists all records for a dayKey ordered by arrivedAt', () async {
      final firstId = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );
      final secondId = await repository.registerArrival(
        childId: 'child-2',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 9),
        createdBy: 'uid-1',
      );
      await repository.registerArrival(
        childId: 'child-3',
        dayKey: '2026-08-29',
        arrivedAt: DateTime.utc(2026, 8, 29, 9),
        createdBy: 'uid-1',
      );

      final records = await repository.listByDayKey(dayKey: '2026-08-30');

      expect(records.map((r) => r.id), [firstId, secondId]);
    });

    test('filters by isOpen when provided', () async {
      final openId = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );
      final closedId = await repository.registerArrival(
        childId: 'child-2',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 9),
        createdBy: 'uid-1',
      );
      await repository.registerDeparture(
        recordId: closedId,
        departedAt: DateTime.utc(2026, 8, 30, 10),
        parecer: const Parecer(),
        updatedBy: 'uid-1',
      );

      final open = await repository.listByDayKey(
        dayKey: '2026-08-30',
        isOpen: true,
      );
      final closed = await repository.listByDayKey(
        dayKey: '2026-08-30',
        isOpen: false,
      );

      expect(open.map((r) => r.id), [openId]);
      expect(closed.map((r) => r.id), [closedId]);
    });
  });

  group('watchByDayKey', () {
    test('emits records for a dayKey ordered by arrivedAt', () async {
      final firstId = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );
      final secondId = await repository.registerArrival(
        childId: 'child-2',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 9),
        createdBy: 'uid-1',
      );
      await repository.registerArrival(
        childId: 'child-3',
        dayKey: '2026-08-29',
        arrivedAt: DateTime.utc(2026, 8, 29, 9),
        createdBy: 'uid-1',
      );

      final records =
          await repository.watchByDayKey(dayKey: '2026-08-30').first;

      expect(records.map((r) => r.id), [firstId, secondId]);
    });

    test('filters by isOpen when provided', () async {
      final openId = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );
      final closedId = await repository.registerArrival(
        childId: 'child-2',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 9),
        createdBy: 'uid-1',
      );
      await repository.registerDeparture(
        recordId: closedId,
        departedAt: DateTime.utc(2026, 8, 30, 10),
        parecer: const Parecer(),
        updatedBy: 'uid-1',
      );

      final open = await repository
          .watchByDayKey(dayKey: '2026-08-30', isOpen: true)
          .first;

      expect(open.map((r) => r.id), [openId]);
    });

    test('emits a new snapshot when a record is added', () async {
      await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );

      final emissions = <int>[];
      final subscription = repository
          .watchByDayKey(dayKey: '2026-08-30')
          .listen((records) => emissions.add(records.length));

      await Future<void>.delayed(Duration.zero);
      await repository.registerArrival(
        childId: 'child-2',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 9),
        createdBy: 'uid-1',
      );
      await Future<void>.delayed(Duration.zero);

      expect(emissions.last, 2);
      await subscription.cancel();
    });
  });

  group('adminUpdateTimestamps', () {
    test('corrects arrivedAt/departedAt on a closed record, keeping isOpen false',
        () async {
      final id = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );
      await repository.registerDeparture(
        recordId: id,
        departedAt: DateTime.utc(2026, 8, 30, 17),
        parecer: const Parecer(),
        updatedBy: 'uid-1',
      );

      await repository.adminUpdateTimestamps(
        recordId: id,
        arrivedAt: DateTime.utc(2026, 8, 30, 9),
        departedAt: DateTime.utc(2026, 8, 30, 18),
        updatedBy: 'admin-1',
      );

      final doc =
          await firestore.collection('presence_records').doc(id).get();
      final data = doc.data()!;

      expect(data['arrivedAt'], Timestamp.fromDate(DateTime.utc(2026, 8, 30, 9)));
      expect(data['departedAt'], Timestamp.fromDate(DateTime.utc(2026, 8, 30, 18)));
      expect(data['isOpen'], isFalse);
      expect(data['dayKey'], '2026-08-30');
      expect(data['updatedBy'], 'admin-1');
    });

    test('recalculates dayKey when the new arrivedAt lands on a different civil day',
        () async {
      final id = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 12),
        createdBy: 'uid-1',
      );

      // 2026-08-31 02:00 UTC is 2026-08-30 23:00 in São Paulo (UTC-3),
      // still the same civil day; push it further to cross into the next
      // São Paulo civil day.
      await repository.adminUpdateTimestamps(
        recordId: id,
        arrivedAt: DateTime.utc(2026, 8, 31, 4),
        updatedBy: 'admin-1',
      );

      final doc =
          await firestore.collection('presence_records').doc(id).get();
      final data = doc.data()!;

      expect(data['dayKey'], '2026-08-31');
    });

    test('clearing departedAt reopens the record (isOpen: true)', () async {
      final id = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );
      await repository.registerDeparture(
        recordId: id,
        departedAt: DateTime.utc(2026, 8, 30, 17),
        parecer: const Parecer(),
        updatedBy: 'uid-1',
      );

      await repository.adminUpdateTimestamps(
        recordId: id,
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        updatedBy: 'admin-1',
      );

      final doc =
          await firestore.collection('presence_records').doc(id).get();
      final data = doc.data()!;

      expect(data['departedAt'], isNull);
      expect(data.containsKey('departedAt'), isTrue);
      expect(data['isOpen'], isTrue);
    });

    test('rejects a departedAt at or before arrivedAt', () {
      expect(
        () => repository.adminUpdateTimestamps(
          recordId: 'whatever',
          arrivedAt: DateTime.utc(2026, 8, 30, 12),
          departedAt: DateTime.utc(2026, 8, 30, 12),
          updatedBy: 'admin-1',
        ),
        throwsArgumentError,
      );
    });
  });

  group('adminDeleteRecord', () {
    test('hard-deletes the record', () async {
      final id = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );

      await repository.adminDeleteRecord(recordId: id);

      final doc =
          await firestore.collection('presence_records').doc(id).get();
      expect(doc.exists, isFalse);
    });
  });

  group('updateParecer', () {
    test('updates the parecer of a closed record without reopening it',
        () async {
      final id = await repository.registerArrival(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: DateTime.utc(2026, 8, 30, 8),
        createdBy: 'uid-1',
      );
      await repository.registerDeparture(
        recordId: id,
        departedAt: DateTime.utc(2026, 8, 30, 17),
        parecer: const Parecer(),
        updatedBy: 'uid-1',
      );

      await repository.updateParecer(
        recordId: id,
        parecer: const Parecer(humor: ParecerHumor.irritado),
        updatedBy: 'uid-2',
      );

      final doc =
          await firestore.collection('presence_records').doc(id).get();
      final data = doc.data()!;

      expect(data['parecer']['humor'], 'irritado');
      expect(data['isOpen'], isFalse);
      expect(data['updatedBy'], 'uid-2');
      // Immutable fields untouched.
      expect(data['departedAt'], isNotNull);
    });
  });
}
