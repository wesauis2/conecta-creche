import 'package:flutter/material.dart';

import '../forms/form_media_answer.dart';
import '../forms/form_media_field.dart';
import '../forms/form_question.dart';
import '../forms/form_question_repository.dart';
import '../presence/presence_answer.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';

/// Fluxo curto "durante o dia": lista filtrada (`durante_dia`, sem ocultas);
/// ocultas acessíveis sob demanda. Cada submit grava um answer object no
/// registro aberto. Ver docs/requisitos/presenca-rotina.md.
class OccurrenceFormScreen extends StatefulWidget {
  const OccurrenceFormScreen({
    super.key,
    required this.profile,
    required this.recordId,
    required this.childName,
    required this.formQuestionRepository,
    required this.presenceRepository,
  });

  final UserProfile profile;
  final String recordId;
  final String childName;
  final FormQuestionRepository formQuestionRepository;
  final PresenceRepository presenceRepository;

  @override
  State<OccurrenceFormScreen> createState() => _OccurrenceFormScreenState();
}

class _OccurrenceFormScreenState extends State<OccurrenceFormScreen> {
  bool _showHidden = false;

  Future<void> _answerQuestion(FormQuestion question) async {
    final value = await showDialog<Object?>(
      context: context,
      builder: (context) => _AnswerValueDialog(question: question),
    );
    if (value == null || !mounted) {
      // Dialog cancelled, or optional without explicit persistable value.
      return;
    }
    // Sentinel for optional questions that were explicitly dismissed without
    // answering: dialog returns false → don't persist.
    if (identical(value, _AnswerValueDialog.cancelled)) {
      return;
    }

    try {
      await widget.presenceRepository.registerAnswer(
        recordId: widget.recordId,
        question: question,
        value: value,
        recordedPhase: RecordedPhase.duranteDia,
        createdBy: widget.profile.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              question.flags.incident
                  ? 'Incidente registrado.'
                  : 'Ocorrência registrada.',
            ),
          ),
        );
      }
    } on PresenceRecordClosedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro já fechado; não é possível registrar.'),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ocorrência · ${widget.childName}'),
      ),
      body: StreamBuilder<List<FormQuestion>>(
        stream: widget.formQuestionRepository.watchQuestions(activeOnly: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as perguntas.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final shortList = all
              .where(
                (q) => q.matchesCaregiverView(FormCaregiverViewFilter.duranteDia),
              )
              .toList();
          final hidden = all
              .where(
                (q) => q.matchesCaregiverView(FormCaregiverViewFilter.ocultas),
              )
              .toList();

          final visible = [
            ...shortList,
            if (_showHidden) ...hidden.where((q) => !shortList.contains(q)),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'Selecione o que ocorreu. Incidentes ficam marcados.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhuma pergunta configurada para durante o dia.\n'
                    'Gestão pode cadastrar em Formulários.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...visible.map((question) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      title: Text(question.prompt),
                      subtitle: question.flags.incident
                          ? const Text('Incidente')
                          : (question.flags.optional
                              ? const Text('Opcional')
                              : null),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _answerQuestion(question),
                    ),
                  );
                }),
              if (hidden.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _showHidden = !_showHidden),
                  child: Text(
                    _showHidden ? 'Ocultar mais perguntas' : 'Mais perguntas',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Dialog to collect a value for one [FormQuestion]. Returns the value to
/// persist, or [_AnswerValueDialog.cancelled] when the user backs out.
class _AnswerValueDialog extends StatefulWidget {
  const _AnswerValueDialog({required this.question});

  /// Sentinel so optional/cancel paths don't collide with a legitimate null
  /// (we never persist null from this dialog).
  static final Object cancelled = Object();

  final FormQuestion question;

  @override
  State<_AnswerValueDialog> createState() => _AnswerValueDialogState();
}

class _AnswerValueDialogState extends State<_AnswerValueDialog> {
  late String? _optionId;
  late final TextEditingController _textController;
  late final TextEditingController _otherController;
  FormMediaAnswer? _media;
  bool _explicitGesture = false;

  FormQuestion get question => widget.question;

  @override
  void initState() {
    super.initState();
    _optionId = question.flags.optional ? null : question.defaultOptionId;
    _textController = TextEditingController();
    _otherController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!question.flags.shouldPersistAnswer(explicitGesture: _explicitGesture)) {
      // Optional without gesture: close without persisting.
      Navigator.of(context).pop(_AnswerValueDialog.cancelled);
      return;
    }

    final Object? value = switch (question.kind) {
      FormQuestionKind.choice => _optionId,
      FormQuestionKind.choiceOther => () {
          final other = _otherController.text.trim();
          return <String, dynamic>{
            'optionId': _optionId,
            if (other.isNotEmpty) 'otherText': other,
          };
        }(),
      FormQuestionKind.text => _textController.text.trim(),
      FormQuestionKind.image ||
      FormQuestionKind.audio ||
      FormQuestionKind.video =>
        _media?.toMap(),
    };

    if (question.kind == FormQuestionKind.choice && _optionId == null) {
      return;
    }
    if (question.kind == FormQuestionKind.choiceOther && _optionId == null) {
      return;
    }
    if (value is String && value.isEmpty) {
      return;
    }
    if (question.kind.isMedia && value == null) {
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(question.prompt),
      content: SingleChildScrollView(
        child: switch (question.kind) {
          FormQuestionKind.choice || FormQuestionKind.choiceOther => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: question.options.map((option) {
                    final selected = _optionId == option.id;
                    return ChoiceChip(
                      label: Text(option.label),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _optionId = option.id;
                        _explicitGesture = true;
                      }),
                    );
                  }).toList(),
                ),
                if (question.kind == FormQuestionKind.choiceOther) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otherController,
                    decoration: const InputDecoration(
                      labelText: 'Outra (texto livre)',
                    ),
                    onChanged: (_) => setState(() => _explicitGesture = true),
                  ),
                ],
              ],
            ),
          FormQuestionKind.text => TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Resposta'),
              onChanged: (_) => setState(() => _explicitGesture = true),
            ),
          FormQuestionKind.image ||
          FormQuestionKind.audio ||
          FormQuestionKind.video =>
            FormMediaField(
              kind: question.kind,
              value: _media,
              onChanged: (media) => setState(() {
                _media = media;
                if (media != null) {
                  _explicitGesture = true;
                }
              }),
            ),
        },
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_AnswerValueDialog.cancelled),
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
