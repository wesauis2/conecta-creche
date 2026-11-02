import 'package:flutter/material.dart';

import '../presence/child.dart';
import '../presence/child_repository.dart';
import '../presence/presence_answer.dart';
import '../presence/presence_clock.dart';
import '../presence/presence_record.dart';
import '../presence/presence_repository.dart';
import '../reports/report_aggregation.dart';

/// Tab Relatórios do responsável: macro→micro só das crianças vinculadas.
/// Ver docs/requisitos/relatorios-responsavel.md e CONTEXT.md.
class RelatoriosScreen extends StatefulWidget {
  RelatoriosScreen({
    super.key,
    required this.responsibleUid,
    required this.childRepository,
    required this.presenceRepository,
    DateTime? now,
  }) : now = now ?? PresenceClock.now();

  final String responsibleUid;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;

  /// Âncora do período (default = agora SP). Injetável nos testes.
  final DateTime now;

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _ChildReportBundle {
  const _ChildReportBundle({
    required this.child,
    required this.today,
    required this.periodRecords,
    required this.answersByRecordId,
    required this.routine,
  });

  final Child child;
  final ChildDaySummary today;
  final List<PresenceRecord> periodRecords;
  final Map<String, List<PresenceAnswer>> answersByRecordId;
  final RoutinePeriodStats routine;
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  late final ReportPeriod _period =
      ReportPeriod.weekContaining(widget.now);
  late final String _focusDayKey = PresenceClock.dayKeyFor(widget.now);

  bool _loading = true;
  String? _error;
  List<_ChildReportBundle> _bundles = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await widget.childRepository
          .listChildrenForResponsible(widget.responsibleUid);

      if (children.isEmpty) {
        if (!mounted) return;
        setState(() {
          _bundles = const [];
          _loading = false;
        });
        return;
      }

      final linkedIds = children.map((c) => c.id).toSet();
      final periodRecords = <PresenceRecord>[];
      for (final dayKey in _period.dayKeys) {
        final dayRecords =
            await widget.presenceRepository.listByDayKey(dayKey: dayKey);
        for (final record in dayRecords) {
          if (linkedIds.contains(record.childId)) {
            periodRecords.add(record);
          }
        }
      }

      final answersByRecordId = <String, List<PresenceAnswer>>{};
      for (final record in periodRecords) {
        answersByRecordId[record.id] =
            await widget.presenceRepository.listAnswers(recordId: record.id);
      }

      final bundles = <_ChildReportBundle>[];
      for (final child in children) {
        final childRecords = periodRecords
            .where((r) => r.childId == child.id)
            .toList(growable: false);
        final childAnswers = <String, List<PresenceAnswer>>{
          for (final record in childRecords)
            record.id: answersByRecordId[record.id] ?? const [],
        };
        bundles.add(
          _ChildReportBundle(
            child: child,
            today: summarizeChildDay(
              dayKey: _focusDayKey,
              records: childRecords,
              answersByRecordId: childAnswers,
            ),
            periodRecords: childRecords,
            answersByRecordId: childAnswers,
            routine: routineStatsForPeriod(records: childRecords),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _bundles = bundles;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _openChildDetail(_ChildReportBundle bundle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _RelatorioChildDetailScreen(
          bundle: bundle,
          period: _period,
          focusDayKey: _focusDayKey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios'),
        actions: [
          IconButton(
            key: const ValueKey('relatorios-reload'),
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Não foi possível carregar os relatórios.\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_bundles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma criança vinculada.\n'
            'Peça à gestão para associar as crianças à sua conta.',
            key: ValueKey('relatorios-empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('relatorios-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Semana ${_period.startDayKey} → ${_period.endDayKey}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Resumo de hoje ($_focusDayKey)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final bundle in _bundles) ...[
          _ChildMacroCard(
            bundle: bundle,
            onTap: () => _openChildDetail(bundle),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ChildMacroCard extends StatelessWidget {
  const _ChildMacroCard({required this.bundle, required this.onTap});

  final _ChildReportBundle bundle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = bundle.today;
    final theme = Theme.of(context);
    return Material(
      key: ValueKey('relatorio-child-${bundle.child.id}'),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bundle.child.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _WellbeingChip(wellbeing: today.wellbeing),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _statusLabel(today.status),
                style: theme.textTheme.bodyMedium,
              ),
              if (today.hasIncident) ...[
                const SizedBox(height: 4),
                Text(
                  'Incidente registrado hoje',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _RoutineStrip(routine: bundle.routine),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineStrip extends StatelessWidget {
  const _RoutineStrip({required this.routine});

  final RoutinePeriodStats routine;

  @override
  Widget build(BuildContext context) {
    final arrival = routine.arrivalMedianMinutes;
    final departure = routine.departureMedianMinutes;
    final arrivalText =
        arrival == null ? '—' : formatMinutesOfDay(arrival);
    final departureText =
        departure == null ? '—' : formatMinutesOfDay(departure);
    final hasOutliers = routine.arrivalOutliers.isNotEmpty ||
        routine.departureOutliers.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rotina na semana · chegada $arrivalText · saída $departureText',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (hasOutliers)
          Text(
            _outlierSummary(routine),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
      ],
    );
  }

  static String _outlierSummary(RoutinePeriodStats routine) {
    final parts = <String>[];
    if (routine.arrivalOutliers.isNotEmpty) {
      parts.add(
        '${routine.arrivalOutliers.length} chegada(s) fora do comum',
      );
    }
    if (routine.departureOutliers.isNotEmpty) {
      parts.add(
        '${routine.departureOutliers.length} saída(s) fora do comum',
      );
    }
    return parts.join(' · ');
  }
}

class _WellbeingChip extends StatelessWidget {
  const _WellbeingChip({required this.wellbeing});

  final ChildDayWellbeing wellbeing;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (wellbeing) {
      ChildDayWellbeing.well => ('Bem', Colors.green.shade700),
      ChildDayWellbeing.attention => ('Atenção', Colors.orange.shade800),
      ChildDayWellbeing.incident => ('Incidente', Theme.of(context).colorScheme.error),
      ChildDayWellbeing.absent => ('Ausente', Colors.blueGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _statusLabel(ChildDayPresenceStatus status) => switch (status) {
      ChildDayPresenceStatus.absent => 'Ausente',
      ChildDayPresenceStatus.present => 'Presente (ainda na creche)',
      ChildDayPresenceStatus.left => 'Saiu',
    };

/// Dia em foco primeiro; demais em ordem cronológica inversa (mais recente).
List<String> _detailDayOrder(List<String> dayKeys, String focusDayKey) {
  final rest = dayKeys.where((k) => k != focusDayKey).toList().reversed;
  return [focusDayKey, ...rest];
}

class _RelatorioChildDetailScreen extends StatelessWidget {
  const _RelatorioChildDetailScreen({
    required this.bundle,
    required this.period,
    required this.focusDayKey,
  });

  final _ChildReportBundle bundle;
  final ReportPeriod period;
  final String focusDayKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlierArrivalIds =
        bundle.routine.arrivalOutliers.map((o) => o.recordId).toSet();
    final outlierDepartureIds =
        bundle.routine.departureOutliers.map((o) => o.recordId).toSet();

    return Scaffold(
      appBar: AppBar(title: Text(bundle.child.name)),
      body: ListView(
        key: ValueKey('relatorio-detail-${bundle.child.id}'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Semana ${period.startDayKey} → ${period.endDayKey}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _RoutineStrip(routine: bundle.routine),
          const SizedBox(height: 16),
          for (final dayKey in _detailDayOrder(period.dayKeys, focusDayKey)) ...[
            _DayDetailSection(
              dayKey: dayKey,
              isFocus: dayKey == focusDayKey,
              summary: summarizeChildDay(
                dayKey: dayKey,
                records: bundle.periodRecords,
                answersByRecordId: bundle.answersByRecordId,
              ),
              answersByRecordId: bundle.answersByRecordId,
              outlierArrivalIds: outlierArrivalIds,
              outlierDepartureIds: outlierDepartureIds,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DayDetailSection extends StatelessWidget {
  const _DayDetailSection({
    required this.dayKey,
    required this.isFocus,
    required this.summary,
    required this.answersByRecordId,
    required this.outlierArrivalIds,
    required this.outlierDepartureIds,
  });

  final String dayKey;
  final bool isFocus;
  final ChildDaySummary summary;
  final Map<String, List<PresenceAnswer>> answersByRecordId;
  final Set<String> outlierArrivalIds;
  final Set<String> outlierDepartureIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              dayKey,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isFocus ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            _WellbeingChip(wellbeing: summary.wellbeing),
          ],
        ),
        const SizedBox(height: 4),
        Text(_statusLabel(summary.status)),
        if (summary.records.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Sem registro neste dia.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final record in summary.records)
          _RecordAnswersTile(
            record: record,
            answers: answersByRecordId[record.id] ?? const [],
            arrivalOutlier: outlierArrivalIds.contains(record.id),
            departureOutlier: outlierDepartureIds.contains(record.id),
          ),
      ],
    );
  }
}

class _RecordAnswersTile extends StatelessWidget {
  const _RecordAnswersTile({
    required this.record,
    required this.answers,
    required this.arrivalOutlier,
    required this.departureOutlier,
  });

  final PresenceRecord record;
  final List<PresenceAnswer> answers;
  final bool arrivalOutlier;
  final bool departureOutlier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrival = formatMinutesOfDay(minutesOfDay(record.arrivedAt));
    final departure = record.departedAt == null
        ? '—'
        : formatMinutesOfDay(minutesOfDay(record.departedAt!));
    final lines = answerDisplayLines(answers);

    return Card(
      key: ValueKey('relatorio-record-${record.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chegada $arrival · Saída $departure',
              style: theme.textTheme.bodyMedium,
            ),
            if (arrivalOutlier)
              Text(
                'Chegada fora do comum nesta semana',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            if (departureOutlier)
              Text(
                'Saída fora do comum nesta semana',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Sem ocorrências neste registro.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(line),
                ),
          ],
        ),
      ),
    );
  }
}
