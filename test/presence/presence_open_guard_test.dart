import 'package:conecta_creche/presence/presence_open_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PresenceOpenGuard.ensureCanCreateArrival', () {
    test('allows arrival when there is no open record for the day', () {
      expect(
        () => PresenceOpenGuard.ensureCanCreateArrival(
          childId: 'child-1',
          dayKey: '2026-08-30',
          hasOpenRecordForDay: false,
        ),
        returnsNormally,
      );
    });

    test('blocks a second open arrival on the same childId+dayKey', () {
      expect(
        () => PresenceOpenGuard.ensureCanCreateArrival(
          childId: 'child-1',
          dayKey: '2026-08-30',
          hasOpenRecordForDay: true,
        ),
        throwsA(isA<OpenPresenceRecordException>()),
      );
    });

    test('exception carries childId and dayKey for diagnostics', () {
      try {
        PresenceOpenGuard.ensureCanCreateArrival(
          childId: 'child-42',
          dayKey: '2026-01-05',
          hasOpenRecordForDay: true,
        );
        fail('expected OpenPresenceRecordException');
      } on OpenPresenceRecordException catch (e) {
        expect(e.childId, 'child-42');
        expect(e.dayKey, '2026-01-05');
        expect(e.toString(), contains('child-42'));
        expect(e.toString(), contains('2026-01-05'));
      }
    });

    test('a new arrival on a different day is allowed even if a previous day is open', () {
      // Open record from yesterday does not block today's arrival: the
      // guard is scoped to the same dayKey (see CONTEXT.md "Registro
      // aberto").
      expect(
        () => PresenceOpenGuard.ensureCanCreateArrival(
          childId: 'child-1',
          dayKey: '2026-08-30',
          hasOpenRecordForDay: false,
        ),
        returnsNormally,
      );
    });
  });
}
