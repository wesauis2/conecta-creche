import 'package:conecta_creche/classes/school_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchoolClass.fromFirestore', () {
    test('maps year, arrays, optional room and audit defaults', () {
      final schoolClass = SchoolClass.fromFirestore('cls-1', {
        'year': 2026,
        'levelIds': <String>['l1', 'l2'],
        'room': '  Sala A  ',
        'caregiverUids': <String>['c1'],
        'childIds': <String>['ch1'],
        'active': true,
      });

      expect(schoolClass.id, 'cls-1');
      expect(schoolClass.year, 2026);
      expect(schoolClass.levelIds, ['l1', 'l2']);
      expect(schoolClass.room, 'Sala A');
      expect(schoolClass.caregiverUids, ['c1']);
      expect(schoolClass.childIds, ['ch1']);
      expect(schoolClass.active, isTrue);
      expect(schoolClass.displayLabel, '2026 · Sala A');
    });

    test('treats blank room as null and builds year-only label', () {
      final schoolClass = SchoolClass.fromFirestore('cls-2', {
        'year': 2025,
        'room': '   ',
      });

      expect(schoolClass.room, isNull);
      expect(schoolClass.levelIds, isEmpty);
      expect(schoolClass.displayLabel, 'Turma 2025');
      expect(schoolClass.active, isTrue);
    });
  });
}
