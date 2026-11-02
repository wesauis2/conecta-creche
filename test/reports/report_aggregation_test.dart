import 'package:conecta_creche/forms/form_question.dart';
import 'package:conecta_creche/presence/presence_answer.dart';
import 'package:conecta_creche/presence/presence_record.dart';
import 'package:conecta_creche/reports/report_aggregation.dart';
import 'package:flutter_test/flutter_test.dart';

PresenceRecord _record({
  required String id,
  required String childId,
  required String dayKey,
  required DateTime arrivedAt,
  DateTime? departedAt,
  bool? isOpen,
}) {
  return PresenceRecord(
    id: id,
    childId: childId,
    dayKey: dayKey,
    arrivedAt: arrivedAt,
    departedAt: departedAt,
    isOpen: isOpen ?? departedAt == null,
  );
}

PresenceAnswer _answer({
  required String id,
  required String prompt,
  required Object? value,
  bool incident = false,
  List<FormQuestionOption> options = const [],
}) {
  return PresenceAnswer(
    id: id,
    questionSnapshot: QuestionSnapshot(
      id: 'q-$id',
      prompt: prompt,
      kind: FormQuestionKind.choice,
      options: options,
    ),
    value: value,
    flagsSnapshot: FormQuestionFlags(duranteDia: true, incident: incident),
    recordedPhase: RecordedPhase.duranteDia,
    recordedAt: DateTime.utc(2026, 11, 2, 14),
  );
}

void main() {
  group('ReportPeriod.weekContaining', () {
    test('semana Dom–Sáb contendo uma segunda-feira', () {
      // 2026-11-02 é segunda; semana = Dom 01 → Sáb 07
      final period = ReportPeriod.weekContaining(DateTime(2026, 11, 2));
      expect(period.startDayKey, '2026-11-01');
      expect(period.endDayKey, '2026-11-07');
      expect(period.dayKeys, [
        '2026-11-01',
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
        '2026-11-07',
      ]);
    });

    test('domingo inicia a própria semana', () {
      final period = ReportPeriod.weekContaining(DateTime(2026, 11, 1));
      expect(period.startDayKey, '2026-11-01');
      expect(period.endDayKey, '2026-11-07');
    });
  });

  group('summarizeChildDay', () {
    test('ausente quando não há registros no dia', () {
      final summary = summarizeChildDay(
        dayKey: '2026-11-02',
        records: const [],
        answersByRecordId: const {},
      );
      expect(summary.status, ChildDayPresenceStatus.absent);
      expect(summary.hasIncident, isFalse);
      expect(summary.wellbeing, ChildDayWellbeing.absent);
    });

    test('presente quando há registro aberto sem incidente', () {
      final open = _record(
        id: 'r1',
        childId: 'c1',
        dayKey: '2026-11-02',
        arrivedAt: DateTime.utc(2026, 11, 2, 11),
      );
      final summary = summarizeChildDay(
        dayKey: '2026-11-02',
        records: [open],
        answersByRecordId: const {},
      );
      expect(summary.status, ChildDayPresenceStatus.present);
      expect(summary.wellbeing, ChildDayWellbeing.attention);
    });

    test('saiu (bem) quando todos fechados e sem incidente', () {
      final closed = _record(
        id: 'r1',
        childId: 'c1',
        dayKey: '2026-11-02',
        arrivedAt: DateTime.utc(2026, 11, 2, 11),
        departedAt: DateTime.utc(2026, 11, 2, 20),
      );
      final summary = summarizeChildDay(
        dayKey: '2026-11-02',
        records: [closed],
        answersByRecordId: {
          'r1': [
            _answer(
              id: 'a1',
              prompt: 'Almoçou bem?',
              value: 'sim',
              options: const [
                FormQuestionOption(id: 'sim', label: 'Sim'),
              ],
            ),
          ],
        },
      );
      expect(summary.status, ChildDayPresenceStatus.left);
      expect(summary.hasIncident, isFalse);
      expect(summary.wellbeing, ChildDayWellbeing.well);
    });

    test('incidente tem prioridade no bem-estar', () {
      final closed = _record(
        id: 'r1',
        childId: 'c1',
        dayKey: '2026-11-02',
        arrivedAt: DateTime.utc(2026, 11, 2, 11),
        departedAt: DateTime.utc(2026, 11, 2, 20),
      );
      final summary = summarizeChildDay(
        dayKey: '2026-11-02',
        records: [closed],
        answersByRecordId: {
          'r1': [
            _answer(
              id: 'a1',
              prompt: 'Febre?',
              value: 'sim',
              incident: true,
              options: const [
                FormQuestionOption(id: 'sim', label: 'Sim'),
              ],
            ),
          ],
        },
      );
      expect(summary.hasIncident, isTrue);
      expect(summary.wellbeing, ChildDayWellbeing.incident);
      expect(summary.incidentAnswers, hasLength(1));
    });

    test('ignora registros de outro dayKey', () {
      final other = _record(
        id: 'r1',
        childId: 'c1',
        dayKey: '2026-11-01',
        arrivedAt: DateTime.utc(2026, 11, 1, 11),
      );
      final summary = summarizeChildDay(
        dayKey: '2026-11-02',
        records: [other],
        answersByRecordId: const {},
      );
      expect(summary.status, ChildDayPresenceStatus.absent);
    });
  });

  group('medianMinutesOfDay', () {
    test('retorna null para lista vazia', () {
      expect(medianMinutesOfDay(const []), isNull);
    });

    test('mediana ímpar', () {
      // 08:00, 08:30, 09:00 → 08:30 = 510
      expect(
        medianMinutesOfDay(const [480, 510, 540]),
        510,
      );
    });

    test('mediana par usa média dos dois centrais', () {
      // 08:00 e 09:00 → 08:30 = 510.0
      expect(medianMinutesOfDay(const [480, 540]), 510.0);
    });
  });

  group('routineStatsForPeriod', () {
    test('calcula mediana de chegada/saída e marca outliers', () {
      final records = [
        _record(
          id: 'r1',
          childId: 'c1',
          dayKey: '2026-11-02',
          arrivedAt: DateTime(2026, 11, 2, 8, 0),
          departedAt: DateTime(2026, 11, 2, 17, 0),
        ),
        _record(
          id: 'r2',
          childId: 'c1',
          dayKey: '2026-11-03',
          arrivedAt: DateTime(2026, 11, 3, 8, 10),
          departedAt: DateTime(2026, 11, 3, 17, 5),
        ),
        _record(
          id: 'r3',
          childId: 'c1',
          dayKey: '2026-11-04',
          arrivedAt: DateTime(2026, 11, 4, 8, 5),
          departedAt: DateTime(2026, 11, 4, 17, 0),
        ),
        // outlier: chegou ~1h30 depois
        _record(
          id: 'r4',
          childId: 'c1',
          dayKey: '2026-11-05',
          arrivedAt: DateTime(2026, 11, 5, 9, 40),
          departedAt: DateTime(2026, 11, 5, 17, 10),
        ),
      ];

      final stats = routineStatsForPeriod(
        records: records,
        outlierThresholdMinutes: 30,
      );

      expect(stats.arrivalMedianMinutes, isNotNull);
      expect(stats.departureMedianMinutes, isNotNull);
      expect(stats.arrivalOutliers.map((o) => o.recordId), contains('r4'));
      expect(stats.departureOutliers, isEmpty);
    });

    test('sem registros → medianas nulas e sem outliers', () {
      final stats = routineStatsForPeriod(records: const []);
      expect(stats.arrivalMedianMinutes, isNull);
      expect(stats.departureMedianMinutes, isNull);
      expect(stats.arrivalOutliers, isEmpty);
      expect(stats.departureOutliers, isEmpty);
    });
  });

  group('formatMinutesOfDay', () {
    test('formata HH:mm', () {
      expect(formatMinutesOfDay(510), '08:30');
      expect(formatMinutesOfDay(0), '00:00');
      expect(formatMinutesOfDay(125), '02:05');
    });
  });

  group('answerDisplayLines', () {
    test('usa rótulos do snapshot, não ids crus', () {
      final answers = [
        _answer(
          id: 'a1',
          prompt: 'Humor',
          value: 'feliz',
          options: const [
            FormQuestionOption(id: 'feliz', label: 'Feliz'),
            FormQuestionOption(id: 'triste', label: 'Triste'),
          ],
        ),
      ];
      final lines = answerDisplayLines(answers);
      expect(lines, ['Humor: Feliz']);
      expect(lines.first, isNot(contains('feliz')));
    });
  });
}
