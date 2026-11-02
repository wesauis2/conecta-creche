import 'package:flutter/material.dart';

import '../presence/child.dart';
import '../presence/child_repository.dart';
import '../presence/presence_answer.dart';
import '../presence/presence_clock.dart';
import '../presence/presence_repository.dart';

/// Visão global de incidentes para gestão/admin (tab Incidentes do shell).
/// Lista answers com `flagsSnapshot.incident`, com filtros por dia e criança.
/// Ver docs/requisitos/shell-navegacao.md e CONTEXT.md "Incidente".
class IncidentesScreen extends StatefulWidget {
  IncidentesScreen({
    super.key,
    required this.presenceRepository,
    required this.childRepository,
    String? initialDayKey,
  }) : initialDayKey = initialDayKey ?? PresenceClock.todayDayKey();

  final PresenceRepository presenceRepository;
  final ChildRepository childRepository;

  /// Dia civil inicial do filtro (default = hoje SP). `null` no state interno
  /// significa "todos os dias"; o construtor só escolhe o default inicial.
  final String initialDayKey;

  @override
  State<IncidentesScreen> createState() => _IncidentesScreenState();
}

class _IncidentesScreenState extends State<IncidentesScreen> {
  late String? _dayKey = widget.initialDayKey;
  String? _childId;
  List<Child> _children = const [];
  List<PresenceIncident> _incidents = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final children = await widget.childRepository.listActiveChildren();
      if (!mounted) return;
      setState(() => _children = children);
      await _reload();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final incidents = await widget.presenceRepository.listIncidents(
        dayKey: _dayKey,
        childId: _childId,
      );
      if (!mounted) return;
      setState(() {
        _incidents = incidents;
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

  String _childName(String childId) {
    for (final child in _children) {
      if (child.id == childId) return child.name;
    }
    return childId;
  }

  Future<void> _pickDay() async {
    final now = PresenceClock.now();
    final initial = _dayKey != null
        ? DateTime.tryParse(_dayKey!) ?? now
        : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      helpText: 'Filtrar por dia',
      cancelText: 'Todos',
      confirmText: 'Filtrar',
    );
    if (!mounted) return;
    // cancelText still returns null — treat as "todos os dias".
    setState(() {
      _dayKey = picked == null ? null : PresenceClock.dayKeyFor(picked);
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidentes'),
        actions: [
          IconButton(
            key: const ValueKey('incidentes-reload'),
            tooltip: 'Atualizar',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('incidentes-day-filter'),
                    onPressed: _pickDay,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _dayKey == null ? 'Todos os dias' : _dayKey!,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey('incidentes-child-filter'),
                    initialValue: _childId,
                    decoration: const InputDecoration(
                      labelText: 'Criança',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      for (final child in _children)
                        DropdownMenuItem<String?>(
                          value: child.id,
                          child: Text(child.name),
                        ),
                    ],
                    onChanged: (value) async {
                      setState(() => _childId = value);
                      await _reload();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
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
            'Não foi possível carregar os incidentes.\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_incidents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum incidente neste filtro.',
            key: ValueKey('incidentes-empty'),
          ),
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('incidentes-list'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      itemCount: _incidents.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final incident = _incidents[index];
        final answer = incident.answer;
        final when = answer.recordedAt ?? answer.createdAt;
        final subtitle = [
          incident.dayKey,
          if (when != null) _formatTime(when),
          answer.displayValue,
        ].where((s) => s.isNotEmpty).join(' · ');

        return ListTile(
          key: ValueKey('incident-${answer.id}'),
          leading: const Icon(Icons.warning_amber_outlined),
          title: Text(_childName(incident.childId)),
          subtitle: Text(
            '${answer.questionSnapshot.prompt}\n$subtitle',
          ),
          isThreeLine: true,
        );
      },
    );
  }

  static String _formatTime(DateTime when) {
    final local = when.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
