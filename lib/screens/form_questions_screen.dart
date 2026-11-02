import 'package:flutter/material.dart';

import '../forms/form_media_answer.dart';
import '../forms/form_question.dart';
import '../forms/form_question_repository.dart';
import '../users/user_profile.dart';

/// Gestão+ configura a lista única de perguntas (ordem DnD, badges, filtros
/// que simulam a visão do cuidador). See CONTEXT.md "Formulário configurável".
class FormQuestionsScreen extends StatefulWidget {
  const FormQuestionsScreen({
    super.key,
    required this.profile,
    required this.formQuestionRepository,
  });

  final UserProfile profile;
  final FormQuestionRepository formQuestionRepository;

  @override
  State<FormQuestionsScreen> createState() => _FormQuestionsScreenState();
}

class _FormQuestionsScreenState extends State<FormQuestionsScreen> {
  FormCaregiverViewFilter _filter = FormCaregiverViewFilter.todas;

  Future<void> _reorder(List<FormQuestion> visible, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) {
      return;
    }

    // Reorder only within the current filtered view, then splice into the
    // full active+inactive list order by rewriting sortIndex for all ids.
    final all = await widget.formQuestionRepository.listQuestions();
    final visibleIds = visible.map((q) => q.id).toList();
    final moved = visibleIds.removeAt(oldIndex);
    visibleIds.insert(newIndex, moved);

    final remaining = all.map((q) => q.id).where((id) => !visibleIds.contains(id));
    final orderedIds = [...visibleIds, ...remaining];

    try {
      await widget.formQuestionRepository.reorderQuestions(
        orderedIds: orderedIds,
        updatedBy: widget.profile.uid,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível reordenar: $error')),
        );
      }
    }
  }

  Future<void> _openEditor({FormQuestion? existing}) async {
    final result = await showDialog<_QuestionDraft>(
      context: context,
      builder: (context) => _QuestionEditorDialog(initial: existing),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      if (existing == null) {
        await widget.formQuestionRepository.createQuestion(
          prompt: result.prompt,
          kind: result.kind,
          options: result.options,
          defaultOptionId: result.defaultOptionId,
          flags: result.flags,
          active: result.active,
          createdBy: widget.profile.uid,
        );
      } else {
        await widget.formQuestionRepository.updateQuestion(
          questionId: existing.id,
          prompt: result.prompt,
          kind: result.kind,
          options: result.options,
          defaultOptionId: result.defaultOptionId,
          clearDefaultOptionId: result.defaultOptionId == null,
          flags: result.flags,
          active: result.active,
          updatedBy: widget.profile.uid,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    }
  }

  Future<void> _setActive(FormQuestion question, bool active) async {
    try {
      await widget.formQuestionRepository.updateQuestion(
        questionId: question.id,
        active: active,
        updatedBy: widget.profile.uid,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.role.canConfigureForms) {
      return Scaffold(
        appBar: AppBar(title: const Text('Formulários')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Você não tem permissão para configurar formulários.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Formulários')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Nova pergunta',
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                for (final filter in FormCaregiverViewFilter.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Filtros simulam a visão do cuidador (lista única).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<FormQuestion>>(
              stream: widget.formQuestionRepository.watchQuestions(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Não foi possível carregar as perguntas.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final visible = snapshot.data!
                    .where((q) => q.matchesCaregiverView(_filter))
                    .toList();

                if (visible.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma pergunta neste filtro.\n'
                        'Toque em + para cadastrar.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
                  itemCount: visible.length,
                  onReorder: (oldIndex, newIndex) =>
                      _reorder(visible, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final question = visible[index];
                    return _QuestionTile(
                      key: ValueKey(question.id),
                      index: index,
                      question: question,
                      onEdit: () => _openEditor(existing: question),
                      onToggleActive: () =>
                          _setActive(question, !question.active),
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
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    super.key,
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onToggleActive,
  });

  final int index;
  final FormQuestion question;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final badges = <String>[
      question.kind.badgeLabel,
      if (question.flags.optional) 'Opcional',
      if (question.flags.incident) 'Incidente',
      if (question.flags.oculta) 'Oculta',
      if (question.flags.duranteDia) 'Durante o dia',
      if (question.flags.saida) 'Saída',
      if (!question.active) 'Inativa',
    ];

    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(question.prompt),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final label in badges)
              Chip(
                label: Text(label, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              ),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: question.active ? 'Inativar' : 'Reativar',
        onPressed: onToggleActive,
        icon: Icon(
          question.active ? Icons.block_outlined : Icons.restore_outlined,
        ),
      ),
      onTap: onEdit,
      isThreeLine: true,
    );
  }
}

class _QuestionDraft {
  const _QuestionDraft({
    required this.prompt,
    required this.kind,
    required this.options,
    required this.defaultOptionId,
    required this.flags,
    required this.active,
  });

  final String prompt;
  final FormQuestionKind kind;
  final List<FormQuestionOption> options;
  final String? defaultOptionId;
  final FormQuestionFlags flags;
  final bool active;
}

class _QuestionEditorDialog extends StatefulWidget {
  const _QuestionEditorDialog({this.initial});

  final FormQuestion? initial;

  @override
  State<_QuestionEditorDialog> createState() => _QuestionEditorDialogState();
}

class _QuestionEditorDialogState extends State<_QuestionEditorDialog> {
  late final TextEditingController _promptController;
  late final TextEditingController _optionsController;
  late FormQuestionKind _kind;
  late FormQuestionFlags _flags;
  late bool _active;
  String? _defaultOptionId;

  bool get _needsOptions =>
      _kind == FormQuestionKind.choice || _kind == FormQuestionKind.choiceOther;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _promptController = TextEditingController(text: initial?.prompt ?? '');
    _optionsController = TextEditingController(
      text: (initial?.options ?? const [])
          .map((o) => o.label)
          .join('\n'),
    );
    _kind = initial?.kind ?? FormQuestionKind.choice;
    _flags = initial?.flags ?? const FormQuestionFlags(saida: true);
    _active = initial?.active ?? true;
    _defaultOptionId = initial?.defaultOptionId;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  List<FormQuestionOption> _parseOptions() {
    final lines = _optionsController.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return [
      for (var i = 0; i < lines.length; i++)
        FormQuestionOption(id: 'opt_$i', label: lines[i]),
    ];
  }

  void _submit() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      return;
    }
    final options = _needsOptions ? _parseOptions() : <FormQuestionOption>[];
    String? defaultId = _defaultOptionId;
    if (_needsOptions && options.isNotEmpty) {
      final ids = options.map((o) => o.id).toSet();
      if (defaultId == null || !ids.contains(defaultId)) {
        defaultId = options.first.id;
      }
    } else {
      defaultId = null;
    }

    Navigator.of(context).pop(
      _QuestionDraft(
        prompt: prompt,
        kind: _kind,
        options: options,
        defaultOptionId: defaultId,
        flags: _flags,
        active: _active,
      ),
    );
  }

  Widget _flagSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = _needsOptions ? _parseOptions() : const <FormQuestionOption>[];

    return AlertDialog(
      title: Text(widget.initial == null ? 'Nova pergunta' : 'Editar pergunta'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _promptController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Pergunta'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<FormQuestionKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final kind in FormQuestionKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(kind.badgeLabel),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _kind = value);
                  }
                },
              ),
              if (_kind.isMedia) ...[
                const SizedBox(height: 8),
                Text(
                  kFormMediaSparkNotice,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (_needsOptions) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Opções (uma por linha)',
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                ),
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: options.any((o) => o.id == _defaultOptionId)
                        ? _defaultOptionId
                        : options.first.id,
                    decoration: const InputDecoration(
                      labelText: 'Padrão (visual)',
                      helperText:
                          'Em opcional explícita, o padrão não grava sem gesto.',
                    ),
                    items: [
                      for (final option in options)
                        DropdownMenuItem(
                          value: option.id,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _defaultOptionId = value),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              _flagSwitch(
                label: 'Durante o dia',
                value: _flags.duranteDia,
                onChanged: (v) =>
                    setState(() => _flags = _flags.copyWith(duranteDia: v)),
              ),
              _flagSwitch(
                label: 'Saída',
                value: _flags.saida,
                onChanged: (v) =>
                    setState(() => _flags = _flags.copyWith(saida: v)),
              ),
              _flagSwitch(
                label: 'Oculta',
                value: _flags.oculta,
                onChanged: (v) =>
                    setState(() => _flags = _flags.copyWith(oculta: v)),
              ),
              _flagSwitch(
                label: 'Incidente',
                value: _flags.incident,
                onChanged: (v) =>
                    setState(() => _flags = _flags.copyWith(incident: v)),
              ),
              _flagSwitch(
                label: 'Opcional explícita',
                value: _flags.optional,
                onChanged: (v) =>
                    setState(() => _flags = _flags.copyWith(optional: v)),
              ),
              _flagSwitch(
                label: 'Ativa',
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
