import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../presence/child.dart';
import '../presence/child_repository.dart';
import '../presence/parecer.dart';
import '../presence/presence_clock.dart';
import '../presence/presence_record.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import 'children_screen.dart';
import 'parecer_form_screen.dart';

enum _GestaoView { semana, mes }

enum _GestaoFilter { presentes, sairam }

const List<String> _dowLabels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
const List<String> _monthAbbrevs = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];
const List<String> _monthNames = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];

/// Open/closed record counts for a single civil day, used for the calendar
/// cell stats.
class _DayStats {
  const _DayStats({required this.open, required this.closed});

  static const empty = _DayStats(open: 0, closed: 0);

  final int open;
  final int closed;

  factory _DayStats.fromRecords(List<PresenceRecord> records) {
    var open = 0;
    var closed = 0;
    for (final record in records) {
      if (record.isOpen) {
        open++;
      } else {
        closed++;
      }
    }
    return _DayStats(open: open, closed: closed);
  }
}

/// Gestão/admin's aggregate presença home: semana/mês (Dom→Sáb), gesture
/// navigation without textual hints, and the selected day's list embedded
/// below (multi-chip Presentes/Saíram, aviso de abertos). See CONTEXT.md
/// "Visão da gestão" / "Calendário da gestão" and
/// `.scratch/registro-presenca/prototypes/gestao-agregado.html`.
///
/// Deliberately self-contained (does not import [PresenceDayScreen]) so this
/// ticket doesn't need to touch that file while it's evolving in parallel
/// for the cuidador flows.
class PresenceGestaoScreen extends StatefulWidget {
  PresenceGestaoScreen({
    super.key,
    required this.profile,
    required this.childRepository,
    required this.presenceRepository,
    this.appBarLeadingActions = const [],
    DateTime? initialDate,
  }) : initialDate = initialDate ?? PresenceClock.now();

  final UserProfile profile;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;

  /// Extra actions rendered before "Crianças" (e.g. shortcuts to the user's
  /// profile) when this screen owns the app's only app bar.
  final List<Widget> appBarLeadingActions;

  /// Overridable for tests; defaults to "now" in São Paulo civil time.
  final DateTime initialDate;

  @override
  State<PresenceGestaoScreen> createState() => _PresenceGestaoScreenState();
}

class _PresenceGestaoScreenState extends State<PresenceGestaoScreen> {
  late tz.TZDateTime _anchor;
  late String _selectedDayKey;
  _GestaoView _view = _GestaoView.semana;
  final Set<_GestaoFilter> _filters = {};
  Map<String, _DayStats> _stats = {};

  late final Stream<List<Child>> _childrenStream =
      widget.childRepository.watchChildren();

  static tz.TZDateTime _spDate(int year, int month, int day) =>
      tz.TZDateTime(PresenceClock.saoPauloLocation, year, month, day);

  static tz.TZDateTime _dateOnlyInSaoPaulo(DateTime when) {
    final sp = tz.TZDateTime.from(when, PresenceClock.saoPauloLocation);
    return _spDate(sp.year, sp.month, sp.day);
  }

  static tz.TZDateTime _parseDayKey(String key) {
    final parts = key.split('-');
    return _spDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  void initState() {
    super.initState();
    _anchor = _dateOnlyInSaoPaulo(widget.initialDate);
    _selectedDayKey = PresenceClock.dayKeyFor(_anchor);
    _reloadStats();
  }

  List<tz.TZDateTime> _weekDays(tz.TZDateTime anchor) {
    // DateTime.weekday: Mon=1..Sun=7; `% 7` maps Sun to 0 so the week always
    // starts on domingo. See CONTEXT.md "Calendário da gestão".
    final start = anchor.subtract(Duration(days: anchor.weekday % 7));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  List<tz.TZDateTime?> _monthCells(tz.TZDateTime anchor) {
    final first = _spDate(anchor.year, anchor.month, 1);
    final leading = first.weekday % 7;
    final daysInMonth = _spDate(anchor.year, anchor.month + 1, 0).day;
    final cells = <tz.TZDateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++) _spDate(anchor.year, anchor.month, d),
    ];
    final remainder = (7 - cells.length % 7) % 7;
    cells.addAll(List.filled(remainder, null));
    return cells;
  }

  List<List<tz.TZDateTime?>> _chunk7(List<tz.TZDateTime?> cells) {
    final rows = <List<tz.TZDateTime?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }
    return rows;
  }

  Future<void> _reloadStats() async {
    final days = _view == _GestaoView.semana
        ? _weekDays(_anchor)
        : _monthCells(_anchor).whereType<tz.TZDateTime>().toList();

    final entries = await Future.wait(days.map((day) async {
      final key = PresenceClock.dayKeyFor(day);
      final records = await widget.presenceRepository.listByDayKey(dayKey: key);
      return MapEntry(key, _DayStats.fromRecords(records));
    }));

    if (!mounted) {
      return;
    }
    setState(() => _stats = Map.fromEntries(entries));
  }

  void _shiftPeriod(int delta) {
    setState(() {
      _anchor = _view == _GestaoView.semana
          ? _anchor.add(Duration(days: 7 * delta))
          : _spDate(_anchor.year, _anchor.month + delta, 1);
    });
    _reloadStats();
  }

  void _setView(_GestaoView view) {
    if (view == _view) {
      return;
    }
    setState(() => _view = view);
    _reloadStats();
  }

  /// "↑ no mês aprofunda para semana": switches to the week that contains
  /// the currently selected day, without any textual hint in the UI.
  void _deepenToWeek() {
    if (_view != _GestaoView.mes) {
      return;
    }
    setState(() {
      _view = _GestaoView.semana;
      _anchor = _parseDayKey(_selectedDayKey);
    });
    _reloadStats();
  }

  void _selectDay(tz.TZDateTime day) {
    setState(() => _selectedDayKey = PresenceClock.dayKeyFor(day));
  }

  bool _matchesFilter(PresenceRecord record) {
    if (_filters.isEmpty) {
      return true;
    }
    if (record.isOpen && _filters.contains(_GestaoFilter.presentes)) {
      return true;
    }
    if (!record.isOpen && _filters.contains(_GestaoFilter.sairam)) {
      return true;
    }
    return false;
  }

  String _filterLabel(_GestaoFilter filter) => switch (filter) {
        _GestaoFilter.presentes => 'Presentes',
        _GestaoFilter.sairam => 'Saíram',
      };

  /// pt-BR empty state for the embedded list once the day has records but
  /// the selected chips exclude all of them (only possible with exactly one
  /// chip selected; none selected shows both, per CONTEXT.md "Filtro de
  /// presença (gestão, detalhe do dia)").
  String _filteredEmptyMessage() {
    if (_filters.length == 1 && _filters.contains(_GestaoFilter.presentes)) {
      return 'Nenhuma criança presente neste dia.';
    }
    if (_filters.length == 1 && _filters.contains(_GestaoFilter.sairam)) {
      return 'Nenhuma criança saiu neste dia.';
    }
    return 'Nada nos filtros selecionados.';
  }

  String _rangeLabel() {
    if (_view == _GestaoView.semana) {
      final days = _weekDays(_anchor);
      final start = days.first;
      final end = days.last;
      if (start.month == end.month) {
        return '${start.day} – ${end.day} ${_monthAbbrevs[end.month - 1]}';
      }
      return '${start.day} ${_monthAbbrevs[start.month - 1]} – '
          '${end.day} ${_monthAbbrevs[end.month - 1]}';
    }
    return '${_monthNames[_anchor.month - 1]} ${_anchor.year}';
  }

  void _openChildren() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChildrenScreen(
          profile: widget.profile,
          childRepository: widget.childRepository,
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String okLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _onRowTap(Child? child, PresenceRecord record) {
    if (child == null) {
      return Future<void>.value();
    }
    return record.isOpen
        ? _confirmDeparture(child, record)
        : _confirmEditParecer(child, record);
  }

  Future<void> _confirmDeparture(Child child, PresenceRecord open) async {
    final confirmed = await _confirm(
      title: 'Registrar saída?',
      body: 'Confirma a saída de ${child.name} agora? '
          'Em seguida você preenche o parecer.',
      okLabel: 'Registrar saída',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final parecer = await Navigator.of(context).push<Parecer>(
      MaterialPageRoute(
        builder: (context) => ParecerFormScreen(
          title: 'Saída · ${child.name}',
          confirmLabel: 'Confirmar saída',
        ),
      ),
    );
    if (parecer == null || !mounted) {
      return;
    }

    try {
      await widget.presenceRepository.registerDeparture(
        recordId: open.id,
        departedAt: PresenceClock.now(),
        parecer: parecer,
        updatedBy: widget.profile.uid,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível registrar a saída: $error')),
        );
      }
    }
  }

  Future<void> _confirmEditParecer(Child child, PresenceRecord record) async {
    final confirmed = await _confirm(
      title: 'Parecer',
      body: 'Abrir o parecer de ${child.name} para correção?',
      okLabel: 'Abrir parecer',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final parecer = await Navigator.of(context).push<Parecer>(
      MaterialPageRoute(
        builder: (context) => ParecerFormScreen(
          title: 'Parecer · ${child.name}',
          confirmLabel: 'Salvar parecer',
          initialParecer: record.parecer,
        ),
      ),
    );
    if (parecer == null || !mounted) {
      return;
    }

    try {
      await widget.presenceRepository.updateParecer(
        recordId: record.id,
        parecer: parecer,
        updatedBy: widget.profile.uid,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar o parecer: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presença'),
        actions: [
          ...widget.appBarLeadingActions,
          if (widget.profile.role.canInactivateChild)
            IconButton(
              onPressed: _openChildren,
              tooltip: 'Crianças',
              icon: const Icon(Icons.groups_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<_GestaoView>(
              segments: const [
                ButtonSegment(value: _GestaoView.semana, label: Text('Semana')),
                ButtonSegment(value: _GestaoView.mes, label: Text('Mês')),
              ],
              selected: {_view},
              onSelectionChanged: (selection) => _setView(selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftPeriod(-1),
                  tooltip: 'Anterior',
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _rangeLabel(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftPeriod(1),
                  tooltip: 'Próximo',
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -200) {
                _shiftPeriod(1);
              } else if (velocity > 200) {
                _shiftPeriod(-1);
              }
            },
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -200) {
                _deepenToWeek();
              }
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: _view == _GestaoView.semana
                  ? _buildWeekGrid()
                  : _buildMonthGrid(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Expanded(child: _buildDayDetail()),
        ],
      ),
    );
  }

  Widget _dowHeader() {
    return Row(
      children: _dowLabels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildWeekGrid() {
    final days = _weekDays(_anchor);
    return Column(
      key: const ValueKey('gestao-week-grid'),
      children: [
        _dowHeader(),
        const SizedBox(height: 4),
        SizedBox(
          height: 68,
          child: Row(
            children: days.map((day) {
              final key = PresenceClock.dayKeyFor(day);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DayCell(
                    key: ValueKey('gestao-day-$key'),
                    day: day,
                    dayKey: key,
                    stats: _stats[key],
                    selected: key == _selectedDayKey,
                    compact: false,
                    onTap: () => _selectDay(day),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    final rows = _chunk7(_monthCells(_anchor));
    return Column(
      key: const ValueKey('gestao-month-grid'),
      children: [
        _dowHeader(),
        const SizedBox(height: 4),
        for (final row in rows)
          SizedBox(
            height: 42,
            child: Row(
              children: row.map((day) {
                if (day == null) {
                  return const Expanded(child: SizedBox.shrink());
                }
                final key = PresenceClock.dayKeyFor(day);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(1.5),
                    child: _DayCell(
                      key: ValueKey('gestao-day-$key'),
                      day: day,
                      dayKey: key,
                      stats: _stats[key],
                      selected: key == _selectedDayKey,
                      compact: true,
                      onTap: () => _selectDay(day),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDayDetail() {
    return StreamBuilder<List<PresenceRecord>>(
      stream: widget.presenceRepository.watchByDayKey(dayKey: _selectedDayKey),
      builder: (context, recordsSnapshot) {
        if (recordsSnapshot.hasError) {
          return _errorMessage('Não foi possível carregar os registros do dia.');
        }
        if (!recordsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = recordsSnapshot.data!;
        final openCount = records.where((r) => r.isOpen).length;

        return StreamBuilder<List<Child>>(
          stream: _childrenStream,
          builder: (context, childrenSnapshot) {
            final childrenById = {
              for (final child in childrenSnapshot.data ?? const <Child>[])
                child.id: child,
            };
            final filtered = records.where(_matchesFilter).toList()
              ..sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (openCount > 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Atenção: $openCount registro'
                      '${openCount == 1 ? '' : 's'} aberto'
                      '${openCount == 1 ? '' : 's'} neste dia.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Wrap(
                    spacing: 8,
                    children: _GestaoFilter.values.map((filter) {
                      return FilterChip(
                        label: Text(_filterLabel(filter)),
                        selected: _filters.contains(filter),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _filters.add(filter);
                            } else {
                              _filters.remove(filter);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('Sem registros neste dia.'))
                      : filtered.isEmpty
                          ? Center(
                              child: Text(_filteredEmptyMessage()),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final record = filtered[index];
                                final child = childrenById[record.childId];
                                return _GestaoRowTile(
                                  childName: child?.name ?? '(criança removida)',
                                  record: record,
                                  onTap: () => _onRowTap(child, record),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _errorMessage(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.dayKey,
    required this.stats,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final tz.TZDateTime day;
  final String dayKey;
  final _DayStats? stats;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = stats ?? _DayStats.empty;
    final hasOpen = s.open > 0;
    final statText = hasOpen
        ? '${s.open} ab.'
        : (s.closed > 0 ? '${s.closed}' : '');

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          alignment: Alignment.topLeft,
          padding: EdgeInsets.all(compact ? 3 : 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 11 : 13,
                ),
              ),
              if (statText.isNotEmpty)
                Text(
                  statText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: hasOpen ? FontWeight.bold : FontWeight.normal,
                    color: hasOpen
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestaoRowTile extends StatelessWidget {
  const _GestaoRowTile({
    required this.childName,
    required this.record,
    required this.onTap,
  });

  final String childName;
  final PresenceRecord record;
  final VoidCallback onTap;

  static String _formatTime(DateTime instant) {
    final saoPaulo = tz.TZDateTime.from(instant, PresenceClock.saoPauloLocation);
    final hour = saoPaulo.hour.toString().padLeft(2, '0');
    final minute = saoPaulo.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final meta = record.isOpen
        ? 'Chegou ${_formatTime(record.arrivedAt)}'
        : 'Saiu ${_formatTime(record.departedAt ?? record.arrivedAt)} · '
            'chegou ${_formatTime(record.arrivedAt)}';
    final hint = record.isOpen ? 'Saída' : 'Parecer';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(meta, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                hint,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
