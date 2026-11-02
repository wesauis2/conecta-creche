import 'package:flutter/material.dart';

import '../forms/form_media_answer.dart';
import '../forms/form_media_field.dart';
import '../forms/form_question.dart';
import '../forms/form_question_repository.dart';
import '../presence/presence_answer.dart';
import '../presence/presence_clock.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';

/// Formulário de saída: obrigatórias `saida`; reaproveita answers do dia;
/// extras/opcionais só para ciência. Confirmar grava drafts com
/// `recordedPhase=saida` e fecha o registro. Ver
/// docs/requisitos/presenca-rotina.md / formularios-configuraveis.md.
class ExitFormScreen extends StatefulWidget {
  const ExitFormScreen({
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
  State<ExitFormScreen> createState() => _ExitFormScreenState();
}

class _ExitFormScreenState extends State<ExitFormScreen> {
  List<FormQuestion>? _questions;
  List<PresenceAnswer>? _existingAnswers;
  Object? _loadError;
  bool _submitting = false;

  /// Draft values for unanswered saida questions (questionId → value).
  final Map<String, Object?> _drafts = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Set<String> _explicitGestures = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final questions = await widget.formQuestionRepository.listQuestions(
        activeOnly: true,
      );
      final answers = await widget.presenceRepository.listAnswers(
        recordId: widget.recordId,
      );
      if (!mounted) {
        return;
      }
      // Prefill required choice defaults so Confirm is enabled without an
      // extra tap (default visual = persisted for non-optional saida).
      for (final q in questions) {
        if (!q.flags.saida || q.flags.optional) {
          continue;
        }
        if (_answerFor(answers, q.id) != null) {
          continue;
        }
        if ((q.kind == FormQuestionKind.choice ||
                q.kind == FormQuestionKind.choiceOther) &&
            q.defaultOptionId != null) {
          _drafts[q.id] = q.defaultOptionId;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _questions = questions;
        _existingAnswers = answers;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loadError = error);
    }
  }

  PresenceAnswer? _existingFor(String questionId) =>
      _answerFor(_existingAnswers, questionId);

  static PresenceAnswer? _answerFor(
    List<PresenceAnswer>? answers,
    String questionId,
  ) {
    if (answers == null) {
      return null;
    }
    for (final a in answers.reversed) {
      if (a.questionSnapshot.id == questionId) {
        return a;
      }
    }
    return null;
  }

  String? _draftOptionId(FormQuestion question) {
    final draft = _drafts[question.id];
    if (draft is String) {
      return draft;
    }
    if (draft is Map && draft['optionId'] is String) {
      return draft['optionId'] as String;
    }
    return null;
  }

  TextEditingController _controllerFor(String questionId) {
    return _textControllers.putIfAbsent(
      questionId,
      () => TextEditingController(),
    );
  }

  List<FormQuestion> get _requiredSaida {
    final all = _questions ?? const <FormQuestion>[];
    return all
        .where((q) => q.flags.saida && !q.flags.optional)
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  }

  List<FormQuestion> get _optionalSaida {
    final all = _questions ?? const <FormQuestion>[];
    return all
        .where((q) => q.flags.saida && q.flags.optional)
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
  }

  /// Answers already recorded that are not required saida rows (ciência).
  List<PresenceAnswer> get _awarenessAnswers {
    final requiredIds = _requiredSaida.map((q) => q.id).toSet();
    final optionalIds = _optionalSaida.map((q) => q.id).toSet();
    return (_existingAnswers ?? const <PresenceAnswer>[])
        .where(
          (a) =>
              !requiredIds.contains(a.questionSnapshot.id) &&
              !optionalIds.contains(a.questionSnapshot.id),
        )
        .toList();
  }

  bool get _canConfirm {
    for (final q in _requiredSaida) {
      if (_existingFor(q.id) != null) {
        continue;
      }
      final draft = _drafts[q.id];
      if (draft == null) {
        return false;
      }
      if (draft is String && draft.trim().isEmpty) {
        return false;
      }
      if (q.kind.isMedia && FormMediaAnswer.tryParse(draft) == null) {
        return false;
      }
    }
    return true;
  }

  List<DepartureAnswerDraft> _collectNewAnswers() {
    final drafts = <DepartureAnswerDraft>[];

    for (final q in [..._requiredSaida, ..._optionalSaida]) {
      if (_existingFor(q.id) != null) {
        // Reuse: do not rewrite an answer already recorded today.
        continue;
      }
      if (q.flags.optional &&
          !q.flags.shouldPersistAnswer(
            explicitGesture: _explicitGestures.contains(q.id),
          )) {
        continue;
      }
      final value = _drafts[q.id];
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      drafts.add(DepartureAnswerDraft(question: q, value: value));
    }
    return drafts;
  }

  Future<void> _confirm() async {
    if (!_canConfirm || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.presenceRepository.registerDeparture(
        recordId: widget.recordId,
        departedAt: PresenceClock.now(),
        updatedBy: widget.profile.uid,
        answers: _collectNewAnswers(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on PresenceRecordClosedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro já fechado; não é possível registrar saída.'),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível registrar a saída: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _formatExisting(PresenceAnswer answer) => answer.displayValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Saída · ${widget.childName}')),
      body: _buildBody(context),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _canConfirm && !_submitting ? _confirm : null,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmar saída'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Não foi possível carregar o formulário de saída.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_questions == null || _existingAnswers == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final required = _requiredSaida;
    final optional = _optionalSaida;
    final awareness = _awarenessAnswers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'Preencha as obrigatórias da saída. O que já foi respondido no dia '
          'é reaproveitado; extras aparecem só para ciência.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (required.isEmpty && optional.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nenhuma pergunta de saída configurada.\n'
              'Gestão pode cadastrar em Formulários.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Text(
            'Obrigatórias',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (required.isEmpty)
            Text(
              'Nenhuma obrigatória de saída.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ...required.map(_buildRequiredQuestion),
        ],
        if (optional.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Extras (só para ciência)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Opcionais — responda só se quiser registrar.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          ...optional.map(_buildOptionalQuestion),
        ],
        if (awareness.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Já no dia (ciência)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...awareness.map((answer) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(answer.questionSnapshot.prompt),
                subtitle: Text(
                  '${_formatExisting(answer)} · Já registrado',
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildRequiredQuestion(FormQuestion question) {
    final existing = _existingFor(question.id);
    if (existing != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.prompt),
            const SizedBox(height: 4),
            Text(
              '${_formatExisting(existing)} · Já registrado',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _AnswerEditor(
        question: question,
        selectedOptionId: _draftOptionId(question),
        textController: _controllerFor(question.id),
        mediaValue: FormMediaAnswer.tryParse(_drafts[question.id]),
        onChoice: (optionId) {
          setState(() {
            _drafts[question.id] = optionId;
            _explicitGestures.add(question.id);
          });
        },
        onChoiceOther: (optionId, otherText) {
          setState(() {
            _drafts[question.id] = <String, dynamic>{
              'optionId': optionId,
              if (otherText.trim().isNotEmpty) 'otherText': otherText.trim(),
            };
            _explicitGestures.add(question.id);
          });
        },
        onText: (text) {
          setState(() {
            _drafts[question.id] = text;
            _explicitGestures.add(question.id);
          });
        },
        onMedia: (media) {
          setState(() {
            if (media == null) {
              _drafts.remove(question.id);
            } else {
              _drafts[question.id] = media.toMap();
              _explicitGestures.add(question.id);
            }
          });
        },
      ),
    );
  }

  Widget _buildOptionalQuestion(FormQuestion question) {
    final existing = _existingFor(question.id);
    if (existing != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${question.prompt} (opcional)'),
            const SizedBox(height: 4),
            Text(
              '${_formatExisting(existing)} · Já registrado',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _AnswerEditor(
        question: question,
        labelSuffix: ' (opcional)',
        selectedOptionId: null,
        textController: _controllerFor(question.id),
        mediaValue: FormMediaAnswer.tryParse(_drafts[question.id]),
        onChoice: (optionId) {
          setState(() {
            _drafts[question.id] = optionId;
            _explicitGestures.add(question.id);
          });
        },
        onChoiceOther: (optionId, otherText) {
          setState(() {
            _drafts[question.id] = <String, dynamic>{
              'optionId': optionId,
              if (otherText.trim().isNotEmpty) 'otherText': otherText.trim(),
            };
            _explicitGestures.add(question.id);
          });
        },
        onText: (text) {
          setState(() {
            _drafts[question.id] = text;
            _explicitGestures.add(question.id);
          });
        },
        onMedia: (media) {
          setState(() {
            if (media == null) {
              _drafts.remove(question.id);
            } else {
              _drafts[question.id] = media.toMap();
              _explicitGestures.add(question.id);
            }
          });
        },
      ),
    );
  }
}

class _AnswerEditor extends StatelessWidget {
  const _AnswerEditor({
    required this.question,
    required this.textController,
    required this.onChoice,
    required this.onChoiceOther,
    required this.onText,
    required this.onMedia,
    this.mediaValue,
    this.selectedOptionId,
    this.labelSuffix = '',
  });

  final FormQuestion question;
  final String? selectedOptionId;
  final TextEditingController textController;
  final FormMediaAnswer? mediaValue;
  final void Function(String optionId) onChoice;
  final void Function(String optionId, String otherText) onChoiceOther;
  final ValueChanged<String> onText;
  final ValueChanged<FormMediaAnswer?> onMedia;
  final String labelSuffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${question.prompt}$labelSuffix',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        switch (question.kind) {
          FormQuestionKind.choice || FormQuestionKind.choiceOther => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: question.options.map((option) {
                    final selected = selectedOptionId == option.id;
                    return ChoiceChip(
                      label: Text(option.label),
                      selected: selected,
                      onSelected: (_) {
                        if (question.kind == FormQuestionKind.choiceOther) {
                          onChoiceOther(option.id, textController.text);
                        } else {
                          onChoice(option.id);
                        }
                      },
                    );
                  }).toList(),
                ),
                if (question.kind == FormQuestionKind.choiceOther) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Outra (texto livre)',
                    ),
                    onChanged: (text) {
                      final optionId = selectedOptionId;
                      if (optionId != null) {
                        onChoiceOther(optionId, text);
                      }
                    },
                  ),
                ],
              ],
            ),
          FormQuestionKind.text => TextField(
              controller: textController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Resposta'),
              onChanged: onText,
            ),
          FormQuestionKind.image ||
          FormQuestionKind.audio ||
          FormQuestionKind.video =>
            FormMediaField(
              kind: question.kind,
              value: mediaValue,
              onChanged: onMedia,
            ),
        },
      ],
    );
  }
}
