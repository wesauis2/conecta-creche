import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/presence/parecer.dart';
import 'package:conecta_creche/presence/presence_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresenceRecord.fromFirestore', () {
    test('maps an open record (no departure, no parecer yet)', () {
      final record = PresenceRecord.fromFirestore('rec-1', {
        'childId': 'child-1',
        'dayKey': '2026-08-30',
        'arrivedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 30, 12)),
        'departedAt': null,
        'isOpen': true,
        'parecer': null,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 30, 12)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 30, 12)),
        'createdBy': 'uid-1',
        'updatedBy': 'uid-1',
      });

      expect(record.id, 'rec-1');
      expect(record.childId, 'child-1');
      expect(record.dayKey, '2026-08-30');
      expect(record.isOpen, isTrue);
      expect(record.departedAt, isNull);
      expect(record.parecer, isNull);
    });

    test('maps a closed record with parecer', () {
      final record = PresenceRecord.fromFirestore('rec-2', {
        'childId': 'child-1',
        'dayKey': '2026-08-30',
        'arrivedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 30, 12)),
        'departedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 30, 18)),
        'isOpen': false,
        'parecer': const Parecer(humor: ParecerHumor.irritado).toMap(),
        'createdBy': 'uid-1',
        'updatedBy': 'uid-2',
      });

      expect(record.isOpen, isFalse);
      expect(record.departedAt, isNotNull);
      expect(record.parecer, isNotNull);
      expect(record.parecer!.humor, ParecerHumor.irritado);
    });
  });

  group('PresenceRecord.toArrivalMap', () {
    test('writes departedAt: null and isOpen: true on create', () {
      final arrivedAt = DateTime.utc(2026, 8, 30, 12);
      final map = PresenceRecord.toArrivalMap(
        childId: 'child-1',
        dayKey: '2026-08-30',
        arrivedAt: arrivedAt,
        createdBy: 'uid-1',
      );

      expect(map['childId'], 'child-1');
      expect(map['dayKey'], '2026-08-30');
      expect(map['departedAt'], isNull);
      expect(map['isOpen'], isTrue);
      expect(map['parecer'], isNull);
      expect(map['createdBy'], 'uid-1');
      expect(map['updatedBy'], 'uid-1');
      expect(map.containsKey('departedAt'), isTrue);
    });
  });

  group('PresenceRecord.toDepartureMap', () {
    test('writes departedAt, isOpen: false and the parecer map', () {
      final departedAt = DateTime.utc(2026, 8, 30, 18);
      const parecer = Parecer(comeu: ParecerComeu.pouco);
      final map = PresenceRecord.toDepartureMap(
        departedAt: departedAt,
        parecer: parecer,
        updatedBy: 'uid-2',
      );

      expect(map['isOpen'], isFalse);
      expect(map['updatedBy'], 'uid-2');
      expect(map['parecer'], parecer.toMap());
      expect(map.containsKey('childId'), isFalse);
      expect(map.containsKey('arrivedAt'), isFalse);
    });
  });
}
