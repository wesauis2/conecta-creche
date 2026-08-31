import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conecta_creche/presence/child.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Child.fromFirestore', () {
    test('maps required and audit fields', () {
      final child = Child.fromFirestore('child-1', {
        'name': 'Ana',
        'active': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        'createdBy': 'uid-1',
        'updatedBy': 'uid-2',
      });

      expect(child.id, 'child-1');
      expect(child.name, 'Ana');
      expect(child.active, isTrue);
      expect(child.createdAt?.isAtSameMomentAs(DateTime.utc(2026, 1, 1)), isTrue);
      expect(child.updatedAt?.isAtSameMomentAs(DateTime.utc(2026, 1, 2)), isTrue);
      expect(child.createdBy, 'uid-1');
      expect(child.updatedBy, 'uid-2');
    });

    test('defaults active to true and audit fields to null when absent', () {
      final child = Child.fromFirestore('child-2', {'name': 'Beto'});

      expect(child.active, isTrue);
      expect(child.createdAt, isNull);
      expect(child.updatedAt, isNull);
      expect(child.createdBy, isNull);
      expect(child.updatedBy, isNull);
    });

    test('maps active: false for inactivated children', () {
      final child = Child.fromFirestore('child-3', {
        'name': 'Caio',
        'active': false,
      });

      expect(child.active, isFalse);
    });
  });
}
