import 'package:conecta_creche/presence/presence_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    PresenceClock.ensureInitialized();
  });

  group('PresenceClock.dayKeyFor', () {
    test('formats a São Paulo instant as YYYY-MM-DD', () {
      final when = tz.TZDateTime(
        PresenceClock.saoPauloLocation,
        2026,
        8,
        30,
        14,
        5,
      );

      expect(PresenceClock.dayKeyFor(when), '2026-08-30');
    });

    test('pads single-digit month and day', () {
      final when = tz.TZDateTime(PresenceClock.saoPauloLocation, 2026, 1, 5);

      expect(PresenceClock.dayKeyFor(when), '2026-01-05');
    });

    test('converts a UTC instant near São Paulo midnight to the correct civil day', () {
      // 2026-08-30 02:30 UTC-03 (SP, standard time, no DST) == 2026-08-30 05:30 UTC.
      final utcInstant = DateTime.utc(2026, 8, 30, 5, 30);

      expect(PresenceClock.dayKeyFor(utcInstant), '2026-08-30');
    });

    test('a UTC instant just before São Paulo midnight belongs to the previous civil day', () {
      // 2026-08-29 23:59 UTC-03 == 2026-08-30 02:59 UTC.
      final utcInstant = DateTime.utc(2026, 8, 30, 2, 59);

      expect(PresenceClock.dayKeyFor(utcInstant), '2026-08-29');
    });
  });

  group('PresenceClock.now / todayDayKey', () {
    test('now() returns an instant anchored to America/Sao_Paulo', () {
      final now = PresenceClock.now();

      expect(now.location, PresenceClock.saoPauloLocation);
    });

    test('todayDayKey() matches dayKeyFor(now())', () {
      final now = PresenceClock.now();

      expect(PresenceClock.todayDayKey(), PresenceClock.dayKeyFor(now));
    });
  });
}
