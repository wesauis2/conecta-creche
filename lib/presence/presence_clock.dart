import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Civil-day ("dia civil") helpers for the presença feature.
///
/// All operational instants (`arrivedAt`, `departedAt`) and the `dayKey`
/// partition are anchored to `America/Sao_Paulo`, regardless of the device's
/// local timezone or clock. See
/// `.scratch/registro-presenca/research/dia-civil-firestore.md`.
class PresenceClock {
  PresenceClock._();

  static const String _zoneName = 'America/Sao_Paulo';

  static bool _initialized = false;
  static late tz.Location _location;

  /// Loads the IANA timezone database. Safe to call more than once.
  static void ensureInitialized() {
    if (_initialized) {
      return;
    }
    tzdata.initializeTimeZones();
    _location = tz.getLocation(_zoneName);
    _initialized = true;
  }

  /// The `America/Sao_Paulo` [tz.Location], used for every presença instant.
  static tz.Location get saoPauloLocation {
    ensureInitialized();
    return _location;
  }

  /// The current instant, expressed in São Paulo civil time.
  static tz.TZDateTime now() => tz.TZDateTime.now(saoPauloLocation);

  /// Civil day key (`YYYY-MM-DD`) for [when] in São Paulo time.
  ///
  /// Accepts any [DateTime] (UTC, another zone, or already a
  /// [tz.TZDateTime]) and converts the underlying instant before formatting.
  static String dayKeyFor(DateTime when) {
    final location = saoPauloLocation;
    final spWhen = when is tz.TZDateTime && when.location == location
        ? when
        : tz.TZDateTime.from(when, location);
    return _format(spWhen);
  }

  /// Civil day key for "now" in São Paulo.
  static String todayDayKey() => dayKeyFor(now());

  static String _format(tz.TZDateTime when) {
    final year = when.year.toString().padLeft(4, '0');
    final month = when.month.toString().padLeft(2, '0');
    final day = when.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
