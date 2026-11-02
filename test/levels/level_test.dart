import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/levels/level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Level.fromFirestore', () {
    test('maps required and audit fields', () {
      final level = Level.fromFirestore('lvl-1', {
        'name': 'Berçário',
        'sortIndex': 2,
        'active': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        'createdBy': 'uid-1',
        'updatedBy': 'uid-2',
      });

      expect(level.id, 'lvl-1');
      expect(level.name, 'Berçário');
      expect(level.sortIndex, 2);
      expect(level.active, isTrue);
      expect(level.createdBy, 'uid-1');
      expect(level.updatedBy, 'uid-2');
    });

    test('defaults active true, sortIndex 0 and empty name', () {
      final level = Level.fromFirestore('lvl-2', {});

      expect(level.name, '');
      expect(level.sortIndex, 0);
      expect(level.active, isTrue);
      expect(level.createdAt, isNull);
    });
  });
}
