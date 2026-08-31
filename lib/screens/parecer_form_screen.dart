import 'package:flutter/material.dart';

import '../presence/parecer.dart';

/// Full-screen "grupos de botões" form for the fixed 6-question parecer,
/// pushed both when closing a saída and when correcting an already-saved
/// parecer. Returns the selected [Parecer] via `Navigator.pop`, or `null`
/// when cancelled. See CONTEXT.md "Parecer".
class ParecerFormScreen extends StatefulWidget {
  const ParecerFormScreen({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialParecer,
  });

  final String title;
  final String confirmLabel;
  final Parecer? initialParecer;

  @override
  State<ParecerFormScreen> createState() => _ParecerFormScreenState();
}

class _ParecerFormScreenState extends State<ParecerFormScreen> {
  late ParecerChorou _chorou;
  late ParecerComportamento _comportamento;
  late ParecerComeu _comeu;
  late ParecerDormiu _dormiu;
  late ParecerEvacuacoes _evacuacoes;
  late ParecerHumor _humor;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialParecer ?? const Parecer();
    _chorou = initial.chorou;
    _comportamento = initial.comportamento;
    _comeu = initial.comeu;
    _dormiu = initial.dormiu;
    _evacuacoes = initial.evacuacoes;
    _humor = initial.humor;
  }

  Parecer get _current => Parecer(
        chorou: _chorou,
        comportamento: _comportamento,
        comeu: _comeu,
        dormiu: _dormiu,
        evacuacoes: _evacuacoes,
        humor: _humor,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _question<ParecerChorou>(
            label: 'Chorou?',
            options: ParecerChorou.values,
            value: _chorou,
            optionLabel: (value) => value.label,
            onSelected: (value) => setState(() => _chorou = value),
          ),
          _question<ParecerComportamento>(
            label: 'Comportamento?',
            options: ParecerComportamento.values,
            value: _comportamento,
            optionLabel: (value) => value.label,
            onSelected: (value) => setState(() => _comportamento = value),
          ),
          _question<ParecerComeu>(
            label: 'Comeu?',
            options: ParecerComeu.values,
            value: _comeu,
            optionLabel: (value) => value.label,
            onSelected: (value) => setState(() => _comeu = value),
          ),
          _question<ParecerDormiu>(
            label: 'Dormiu?',
            options: ParecerDormiu.values,
            value: _dormiu,
            optionLabel: (value) => value.label,
            onSelected: (value) => setState(() => _dormiu = value),
          ),
          _question<ParecerEvacuacoes>(
            label: 'Evacuações?',
            options: ParecerEvacuacoes.values,
            value: _evacuacoes,
            optionLabel: (value) => value.label,
            onSelected: (value) => setState(() => _evacuacoes = value),
          ),
          _question<ParecerHumor>(
            label: 'Humor geral?',
            options: ParecerHumor.values,
            value: _humor,
            optionLabel: (value) => value.label,
            onSelected: (value) => setState(() => _humor = value),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_current),
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _question<T>({
    required String label,
    required List<T> options,
    required T value,
    required String Function(T option) optionLabel,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = option == value;
              return ChoiceChip(
                label: Text(optionLabel(option)),
                selected: selected,
                onSelected: (_) => onSelected(option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
