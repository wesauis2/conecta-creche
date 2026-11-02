import '../presence/presence_answer.dart';
import '../presence/presence_clock.dart';
import '../presence/presence_record.dart';

/// Estado operacional da criança em um dia civil.
enum ChildDayPresenceStatus {
  /// Sem registro de presença no dia.
  absent,

  /// Há registro aberto (ainda na creche).
  present,

  /// Todos os registros do dia estão fechados (saiu).
  left,
}

/// Leitura macro de bem-estar do dia (UI do responsável).
///
/// "Bem" = saiu + sem incidente (ver docs/requisitos/relatorios-responsavel.md).
enum ChildDayWellbeing {
  well,
  attention,
  incident,
  absent,
}

/// Período civil Dom–Sáb (alinhado ao calendário da gestão).
class ReportPeriod {
  const ReportPeriod({
    required this.startDayKey,
    required this.endDayKey,
    required this.dayKeys,
  });

  final String startDayKey;
  final String endDayKey;
  final List<String> dayKeys;

  /// Semana Dom–Sáb que contém [when] (civil local / SP-agnostic DateTime date).
  factory ReportPeriod.weekContaining(DateTime when) {
    PresenceClock.ensureInitialized();
    final date = DateTime(when.year, when.month, when.day);
    // DateTime.weekday: Mon=1..Sun=7; `% 7` maps Sun→0 so week starts domingo.
    final start = date.subtract(Duration(days: date.weekday % 7));
    final dayKeys = List<String>.generate(7, (i) {
      final d = start.add(Duration(days: i));
      return _formatDayKey(d);
    });
    return ReportPeriod(
      startDayKey: dayKeys.first,
      endDayKey: dayKeys.last,
      dayKeys: dayKeys,
    );
  }

  static String _formatDayKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

/// Resumo macro de um dia para uma criança.
class ChildDaySummary {
  const ChildDaySummary({
    required this.dayKey,
    required this.status,
    required this.hasIncident,
    required this.wellbeing,
    required this.records,
    required this.incidentAnswers,
  });

  final String dayKey;
  final ChildDayPresenceStatus status;
  final bool hasIncident;
  final ChildDayWellbeing wellbeing;
  final List<PresenceRecord> records;
  final List<PresenceAnswer> incidentAnswers;
}

/// Instant de chegada/saída marcado como outlier vs mediana do período.
class RoutineOutlier {
  const RoutineOutlier({
    required this.recordId,
    required this.dayKey,
    required this.minutesOfDay,
    required this.deviationMinutes,
  });

  final String recordId;
  final String dayKey;
  final int minutesOfDay;
  final double deviationMinutes;
}

/// Estatísticas de rotina (mediana + outliers) no período.
class RoutinePeriodStats {
  const RoutinePeriodStats({
    required this.arrivalMedianMinutes,
    required this.departureMedianMinutes,
    required this.arrivalOutliers,
    required this.departureOutliers,
  });

  final double? arrivalMedianMinutes;
  final double? departureMedianMinutes;
  final List<RoutineOutlier> arrivalOutliers;
  final List<RoutineOutlier> departureOutliers;
}

/// Agrega registros + answers de um dia em resumo macro.
ChildDaySummary summarizeChildDay({
  required String dayKey,
  required List<PresenceRecord> records,
  required Map<String, List<PresenceAnswer>> answersByRecordId,
}) {
  final dayRecords =
      records.where((r) => r.dayKey == dayKey).toList(growable: false);

  final ChildDayPresenceStatus status;
  if (dayRecords.isEmpty) {
    status = ChildDayPresenceStatus.absent;
  } else if (dayRecords.any((r) => r.isOpen)) {
    status = ChildDayPresenceStatus.present;
  } else {
    status = ChildDayPresenceStatus.left;
  }

  final incidents = <PresenceAnswer>[];
  for (final record in dayRecords) {
    final answers = answersByRecordId[record.id] ?? const <PresenceAnswer>[];
    for (final answer in answers) {
      if (answer.isIncident) incidents.add(answer);
    }
  }

  final hasIncident = incidents.isNotEmpty;
  final ChildDayWellbeing wellbeing;
  if (status == ChildDayPresenceStatus.absent) {
    wellbeing = ChildDayWellbeing.absent;
  } else if (hasIncident) {
    wellbeing = ChildDayWellbeing.incident;
  } else if (status == ChildDayPresenceStatus.left) {
    wellbeing = ChildDayWellbeing.well;
  } else {
    wellbeing = ChildDayWellbeing.attention;
  }

  return ChildDaySummary(
    dayKey: dayKey,
    status: status,
    hasIncident: hasIncident,
    wellbeing: wellbeing,
    records: dayRecords,
    incidentAnswers: incidents,
  );
}

/// Mediana de minutos desde meia-noite. Lista vazia → null.
/// Par: média aritmética dos dois centrais.
double? medianMinutesOfDay(List<int> minutes) {
  if (minutes.isEmpty) return null;
  final sorted = List<int>.from(minutes)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid].toDouble();
  }
  return (sorted[mid - 1] + sorted[mid]) / 2.0;
}

/// Minutos desde meia-noite do instante local (usa campos wall-clock).
int minutesOfDay(DateTime when) => when.hour * 60 + when.minute;

/// Formata minutos desde meia-noite como `HH:mm`.
String formatMinutesOfDay(num minutes) {
  final total = minutes.round().clamp(0, 24 * 60 - 1);
  final h = (total ~/ 60).toString().padLeft(2, '0');
  final m = (total % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Mediana de chegada/saída no período + outliers (|desvio| ≥ limiar).
RoutinePeriodStats routineStatsForPeriod({
  required List<PresenceRecord> records,
  int outlierThresholdMinutes = 30,
}) {
  final arrivals = <({String recordId, String dayKey, int minutes})>[];
  final departures = <({String recordId, String dayKey, int minutes})>[];

  for (final record in records) {
    arrivals.add((
      recordId: record.id,
      dayKey: record.dayKey,
      minutes: minutesOfDay(record.arrivedAt),
    ));
    final departed = record.departedAt;
    if (departed != null) {
      departures.add((
        recordId: record.id,
        dayKey: record.dayKey,
        minutes: minutesOfDay(departed),
      ));
    }
  }

  final arrivalMedian =
      medianMinutesOfDay(arrivals.map((e) => e.minutes).toList());
  final departureMedian =
      medianMinutesOfDay(departures.map((e) => e.minutes).toList());

  List<RoutineOutlier> outliers(
    List<({String recordId, String dayKey, int minutes})> samples,
    double? median,
  ) {
    if (median == null) return const [];
    final threshold = outlierThresholdMinutes.toDouble();
    final result = <RoutineOutlier>[];
    for (final sample in samples) {
      final deviation = (sample.minutes - median).abs();
      if (deviation >= threshold) {
        result.add(
          RoutineOutlier(
            recordId: sample.recordId,
            dayKey: sample.dayKey,
            minutesOfDay: sample.minutes,
            deviationMinutes: deviation,
          ),
        );
      }
    }
    return result;
  }

  return RoutinePeriodStats(
    arrivalMedianMinutes: arrivalMedian,
    departureMedianMinutes: departureMedian,
    arrivalOutliers: outliers(arrivals, arrivalMedian),
    departureOutliers: outliers(departures, departureMedian),
  );
}

/// Linhas legíveis "pergunta: valor" com rótulos do snapshot.
List<String> answerDisplayLines(List<PresenceAnswer> answers) {
  return [
    for (final answer in answers)
      '${answer.questionSnapshot.prompt}: ${answer.displayValue}',
  ];
}
