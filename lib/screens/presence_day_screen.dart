import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../presence/child.dart';
import '../presence/child_repository.dart';
import '../presence/parecer.dart';
import '../presence/presence_clock.dart';
import '../presence/presence_open_guard.dart';
import '../presence/presence_record.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import 'children_screen.dart';
import 'parecer_form_screen.dart';

enum _PresenceFilter { presentes, sairam, todos }

enum _RowMode { chegada, saida, parecer }

enum _AdminAction { editTimestamps, delete }

class _PresenceRow {
  const _PresenceRow({
    required this.child,
    required this.mode,
    this.open,
    this.lastClosed,
  });

  final Child child;
  final _RowMode mode;
  final PresenceRecord? open;
  final PresenceRecord? lastClosed;

  /// The record admin actions (editar horários/apagar) apply to: the open
  /// one if present, otherwise the most recent closed one. `null` when the
  /// child has no record today (plain chegada row), so there is nothing to
  /// edit or delete.
  PresenceRecord? get activeRecord => open ?? lastClosed;
}

/// Cuidador's operational day detail: chips Presentes/Saíram/Todos
/// (exclusive, default Presentes), tap a row to confirm chegada/saída, and
/// parecer as button groups on saída. See CONTEXT.md "Visão do cuidador" and
/// `.scratch/registro-presenca/prototypes/cuidador-dia.html`.
class PresenceDayScreen extends StatefulWidget {
  PresenceDayScreen({
    super.key,
    required this.profile,
    required this.childRepository,
    required this.presenceRepository,
    this.appBarLeadingActions = const [],
    String? dayKey,
  }) : dayKey = dayKey ?? PresenceClock.todayDayKey();

  final UserProfile profile;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;

  /// Extra actions rendered before "Crianças"/"Nova" (e.g. shortcuts to the
  /// user's profile) when this screen owns the app's only app bar.
  final List<Widget> appBarLeadingActions;

  /// Overridable for tests; defaults to today's São Paulo civil day.
  final String dayKey;

  @override
  State<PresenceDayScreen> createState() => _PresenceDayScreenState();
}

class _PresenceDayScreenState extends State<PresenceDayScreen> {
  _PresenceFilter _filter = _PresenceFilter.presentes;
  late final Stream<List<Child>> _childrenStream =
      widget.childRepository.watchChildren(activeOnly: true);
  late final Stream<List<PresenceRecord>> _recordsStream =
      widget.presenceRepository.watchByDayKey(dayKey: widget.dayKey);

  List<_PresenceRow> _buildRows(
    List<Child> children,
    List<PresenceRecord> records,
  ) {
    final byChild = <String, List<PresenceRecord>>{};
    for (final record in records) {
      byChild.putIfAbsent(record.childId, () => []).add(record);
    }

    final rows = <_PresenceRow>[];
    for (final child in children) {
      final childRecords = byChild[child.id] ?? const <PresenceRecord>[];
      PresenceRecord? open;
      final closed = <PresenceRecord>[];
      for (final record in childRecords) {
        if (record.isOpen) {
          open = record;
        } else {
          closed.add(record);
        }
      }
      closed.sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
      final lastClosed = closed.isEmpty ? null : closed.last;

      switch (_filter) {
        case _PresenceFilter.presentes:
          if (open != null) {
            rows.add(
              _PresenceRow(
                child: child,
                mode: _RowMode.saida,
                open: open,
                lastClosed: lastClosed,
              ),
            );
          }
        case _PresenceFilter.sairam:
          if (open == null && lastClosed != null) {
            rows.add(
              _PresenceRow(
                child: child,
                mode: _RowMode.parecer,
                lastClosed: lastClosed,
              ),
            );
          }
        case _PresenceFilter.todos:
          rows.add(
            _PresenceRow(
              child: child,
              mode: open != null ? _RowMode.saida : _RowMode.chegada,
              open: open,
              lastClosed: lastClosed,
            ),
          );
      }
    }
    rows.sort(
      (a, b) => a.child.name.toLowerCase().compareTo(b.child.name.toLowerCase()),
    );
    return rows;
  }

  Future<void> _onRowTap(_PresenceRow row) {
    switch (row.mode) {
      case _RowMode.chegada:
        return _confirmArrival(row.child);
      case _RowMode.saida:
        return _confirmDeparture(row.child, row.open!);
      case _RowMode.parecer:
        return _confirmEditParecer(row.child, row.lastClosed!);
    }
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

  Future<void> _confirmArrival(Child child) async {
    final confirmed = await _confirm(
      title: 'Registrar chegada?',
      body: 'Confirma a chegada de ${child.name} agora?',
      okLabel: 'Registrar chegada',
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await widget.presenceRepository.registerArrival(
        childId: child.id,
        dayKey: widget.dayKey,
        arrivedAt: PresenceClock.now(),
        createdBy: widget.profile.uid,
      );
      if (mounted) {
        setState(() => _filter = _PresenceFilter.presentes);
      }
    } on OpenPresenceRecordException {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Chegada bloqueada'),
          content: Text(
            '${child.name} já tem registro aberto hoje. '
            'Registre a saída antes.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível registrar a chegada: $error'),
          ),
        );
      }
    }
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
      if (mounted) {
        setState(() => _filter = _PresenceFilter.sairam);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível registrar a saída: $error'),
          ),
        );
      }
    }
  }

  Future<void> _confirmEditParecer(
    Child child,
    PresenceRecord lastClosed,
  ) async {
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
          initialParecer: lastClosed.parecer,
        ),
      ),
    );
    if (parecer == null || !mounted) {
      return;
    }

    try {
      await widget.presenceRepository.updateParecer(
        recordId: lastClosed.id,
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

  /// Admin-only: edit `arrivedAt`/`departedAt`, recalculating `dayKey`/
  /// `isOpen`. See CONTEXT.md "Chegada" / "Saída" and ticket 06.
  Future<void> _adminEditTimestamps(Child child, PresenceRecord record) async {
    final result = await showDialog<_AdminTimestampsResult>(
      context: context,
      builder: (context) => _AdminEditTimestampsDialog(
        childName: child.name,
        record: record,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      await widget.presenceRepository.adminUpdateTimestamps(
        recordId: record.id,
        arrivedAt: result.arrivedAt,
        departedAt: result.departedAt,
        updatedBy: widget.profile.uid,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar os horários: $error'),
          ),
        );
      }
    }
  }

  /// Admin-only: hard-deletes a presence record after confirmation. See
  /// ticket 06.
  Future<void> _adminDeleteRecord(Child child, PresenceRecord record) async {
    final confirmed = await _confirm(
      title: 'Apagar registro?',
      body: 'Esta ação apaga definitivamente o registro de presença de '
          '${child.name} de hoje. Não é possível desfazer.',
      okLabel: 'Apagar',
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await widget.presenceRepository.adminDeleteRecord(recordId: record.id);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível apagar o registro: $error')),
        );
      }
    }
  }

  Future<void> _createChild() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewChildDialog(),
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    try {
      await widget.childRepository.createChild(
        name: name,
        createdBy: widget.profile.uid,
      );
      if (mounted) {
        setState(() => _filter = _PresenceFilter.todos);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível criar a criança: $error')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Presença'),
        actions: [
          ...widget.appBarLeadingActions,
          TextButton(
            onPressed: _openChildren,
            child: const Text('Crianças'),
          ),
          TextButton(
            onPressed: _createChild,
            child: const Text('Nova'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: _PresenceFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Child>>(
              stream: _childrenStream,
              builder: (context, childrenSnapshot) {
                if (childrenSnapshot.hasError) {
                  return _errorMessage(
                    context,
                    'Não foi possível carregar as crianças.',
                  );
                }
                if (!childrenSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<PresenceRecord>>(
                  stream: _recordsStream,
                  builder: (context, recordsSnapshot) {
                    if (recordsSnapshot.hasError) {
                      return _errorMessage(
                        context,
                        'Não foi possível carregar a presença de hoje.',
                      );
                    }
                    if (!recordsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rows = _buildRows(
                      childrenSnapshot.data!,
                      recordsSnapshot.data!,
                    );
                    if (rows.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _emptyStateMessage(_filter),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final activeRecord = row.activeRecord;
                        final canAdmin = widget.profile.role.canAdminPresence &&
                            activeRecord != null;
                        return _PresenceRowTile(
                          row: row,
                          onTap: () => _onRowTap(row),
                          onAdminEdit: canAdmin
                              ? () =>
                                  _adminEditTimestamps(row.child, activeRecord)
                              : null,
                          onAdminDelete: canAdmin
                              ? () =>
                                  _adminDeleteRecord(row.child, activeRecord)
                              : null,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorMessage(BuildContext context, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );

  String _filterLabel(_PresenceFilter filter) => switch (filter) {
        _PresenceFilter.presentes => 'Presentes',
        _PresenceFilter.sairam => 'Saíram',
        _PresenceFilter.todos => 'Todos',
      };

  /// pt-BR empty state per chip; "Todos" is only empty when there are no
  /// active children at all, so it points at "Nova" instead of a filter.
  String _emptyStateMessage(_PresenceFilter filter) => switch (filter) {
        _PresenceFilter.presentes =>
          'Nenhuma criança presente agora.\nToque em Todos para registrar uma chegada.',
        _PresenceFilter.sairam => 'Nenhuma criança saiu ainda hoje.',
        _PresenceFilter.todos =>
          'Nenhuma criança cadastrada.\nToque em Nova para cadastrar.',
      };
}

class _PresenceRowTile extends StatelessWidget {
  const _PresenceRowTile({
    required this.row,
    required this.onTap,
    this.onAdminEdit,
    this.onAdminDelete,
  });

  final _PresenceRow row;
  final VoidCallback onTap;

  /// Non-null only for `canAdminPresence` roles with a record to act on.
  final VoidCallback? onAdminEdit;
  final VoidCallback? onAdminDelete;

  static String _formatTime(DateTime instant) {
    final saoPaulo = tz.TZDateTime.from(instant, PresenceClock.saoPauloLocation);
    final hour = saoPaulo.hour.toString().padLeft(2, '0');
    final minute = saoPaulo.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final open = row.open;
    final lastClosed = row.lastClosed;
    final meta = open != null
        ? 'Chegou ${_formatTime(open.arrivedAt)}'
        : lastClosed != null
            ? 'Saiu ${_formatTime(lastClosed.departedAt ?? lastClosed.arrivedAt)}'
            : 'Sem registro hoje';
    final hint = switch (row.mode) {
      _RowMode.saida => 'Saída',
      _RowMode.parecer => 'Parecer',
      _RowMode.chegada => 'Chegada',
    };

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
                      row.child.name,
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
              if (onAdminEdit != null && onAdminDelete != null)
                PopupMenuButton<_AdminAction>(
                  tooltip: 'Ações de admin',
                  onSelected: (action) => switch (action) {
                    _AdminAction.editTimestamps => onAdminEdit!(),
                    _AdminAction.delete => onAdminDelete!(),
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _AdminAction.editTimestamps,
                      child: Text('Editar horários'),
                    ),
                    PopupMenuItem(
                      value: _AdminAction.delete,
                      child: Text('Apagar registro'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChildDialog extends StatefulWidget {
  const _NewChildDialog();

  @override
  State<_NewChildDialog> createState() => _NewChildDialogState();
}

class _NewChildDialogState extends State<_NewChildDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova criança'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nome ou apelido'),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Result of [_AdminEditTimestampsDialog]: the corrected instants, ready to
/// pass to `PresenceRepository.adminUpdateTimestamps`. [departedAt] is
/// `null` when the admin left the record open.
class _AdminTimestampsResult {
  const _AdminTimestampsResult({required this.arrivedAt, this.departedAt});

  final DateTime arrivedAt;
  final DateTime? departedAt;
}

const String _adminDateTimeHint = 'dd/mm/aaaa hh:mm';
final RegExp _adminDateTimePattern =
    RegExp(r'^(\d{2})/(\d{2})/(\d{4})\s+(\d{2}):(\d{2})$');

/// Formats [instant] as `dd/mm/aaaa hh:mm` in São Paulo civil time, for
/// prefilling the admin edit dialog's text fields.
String _formatAdminDateTime(DateTime instant) {
  final saoPaulo = tz.TZDateTime.from(instant, PresenceClock.saoPauloLocation);
  final dd = saoPaulo.day.toString().padLeft(2, '0');
  final mm = saoPaulo.month.toString().padLeft(2, '0');
  final yyyy = saoPaulo.year.toString().padLeft(4, '0');
  final hh = saoPaulo.hour.toString().padLeft(2, '0');
  final min = saoPaulo.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min';
}

/// Parses a `dd/mm/aaaa hh:mm` string as a São Paulo civil instant, or
/// returns `null` if it doesn't match the expected shape.
DateTime? _parseAdminDateTime(String input) {
  final match = _adminDateTimePattern.firstMatch(input.trim());
  if (match == null) {
    return null;
  }
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  try {
    return tz.TZDateTime(
      PresenceClock.saoPauloLocation,
      year,
      month,
      day,
      hour,
      minute,
    );
  } on Object {
    return null;
  }
}

/// Admin-only dialog to correct `arrivedAt`/`departedAt`. Leaving "Saída"
/// blank keeps (or reopens) the record as open. See ticket 06.
class _AdminEditTimestampsDialog extends StatefulWidget {
  const _AdminEditTimestampsDialog({
    required this.childName,
    required this.record,
  });

  final String childName;
  final PresenceRecord record;

  @override
  State<_AdminEditTimestampsDialog> createState() =>
      _AdminEditTimestampsDialogState();
}

class _AdminEditTimestampsDialogState
    extends State<_AdminEditTimestampsDialog> {
  late final TextEditingController _arrivedController = TextEditingController(
    text: _formatAdminDateTime(widget.record.arrivedAt),
  );
  late final TextEditingController _departedController = TextEditingController(
    text: widget.record.departedAt == null
        ? ''
        : _formatAdminDateTime(widget.record.departedAt!),
  );
  String? _error;

  @override
  void dispose() {
    _arrivedController.dispose();
    _departedController.dispose();
    super.dispose();
  }

  void _save() {
    final arrivedAt = _parseAdminDateTime(_arrivedController.text);
    if (arrivedAt == null) {
      setState(() => _error = 'Chegada inválida. Use $_adminDateTimeHint.');
      return;
    }

    final departedText = _departedController.text.trim();
    DateTime? departedAt;
    if (departedText.isNotEmpty) {
      departedAt = _parseAdminDateTime(departedText);
      if (departedAt == null) {
        setState(() => _error = 'Saída inválida. Use $_adminDateTimeHint.');
        return;
      }
      if (!departedAt.isAfter(arrivedAt)) {
        setState(() => _error = 'A saída deve ser depois da chegada.');
        return;
      }
    }

    Navigator.of(context).pop(
      _AdminTimestampsResult(arrivedAt: arrivedAt, departedAt: departedAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar horários · ${widget.childName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _arrivedController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Chegada',
              hintText: _adminDateTimeHint,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _departedController,
            decoration: const InputDecoration(
              labelText: 'Saída',
              hintText: _adminDateTimeHint,
              helperText: 'Em branco = registro fica aberto',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}
