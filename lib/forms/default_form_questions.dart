import 'form_question.dart';

/// Entrada versionada do pacote default de `form_questions`.
///
/// [seedKey] é a chave de idempotência gravada no Firestore
/// (`docs/requisitos/formularios-configuraveis.md`).
class DefaultFormQuestion {
  const DefaultFormQuestion({
    required this.seedKey,
    required this.prompt,
    required this.kind,
    this.options = const [],
    this.defaultOptionId,
    required this.flags,
    required this.sortIndex,
  });

  final String seedKey;
  final String prompt;
  final FormQuestionKind kind;
  final List<FormQuestionOption> options;
  final String? defaultOptionId;
  final FormQuestionFlags flags;
  final int sortIndex;
}

const _simNao = [
  FormQuestionOption(id: 'sim', label: 'Sim'),
  FormQuestionOption(id: 'nao', label: 'Não'),
];

const _comeu = [
  FormQuestionOption(id: 'bem', label: 'Bem'),
  FormQuestionOption(id: 'parcial', label: 'Parcial'),
  FormQuestionOption(id: 'pouco', label: 'Pouco'),
  FormQuestionOption(id: 'nao', label: 'Não'),
];

const _tipoRefeicao = [
  FormQuestionOption(id: 'cafe', label: 'Café'),
  FormQuestionOption(id: 'almoco', label: 'Almoço'),
  FormQuestionOption(id: 'lanche', label: 'Lanche'),
  FormQuestionOption(id: 'jantar', label: 'Jantar'),
  FormQuestionOption(id: 'outro', label: 'Outro'),
];

const _dormiu = [
  FormQuestionOption(id: 'sim', label: 'Sim'),
  FormQuestionOption(id: 'cochilou', label: 'Cochilou'),
  FormQuestionOption(id: 'nao', label: 'Não'),
];

const _comportamento = [
  FormQuestionOption(id: 'tranquilo', label: 'Tranquilo'),
  FormQuestionOption(id: 'agitado', label: 'Agitado'),
  FormQuestionOption(id: 'precisou_atencao', label: 'Precisou de atenção'),
];

const _humor = [
  FormQuestionOption(id: 'contente', label: 'Contente'),
  FormQuestionOption(id: 'neutro', label: 'Neutro'),
  FormQuestionOption(id: 'irritado', label: 'Irritado'),
];

const _evacuacoes = [
  FormQuestionOption(id: 'normal', label: 'Normal'),
  FormQuestionOption(id: 'nao_fez', label: 'Não fez'),
  FormQuestionOption(id: 'atencao', label: 'Atenção'),
];

const _chorou = [
  FormQuestionOption(id: 'nao', label: 'Não'),
  FormQuestionOption(id: 'um_pouco', label: 'Um pouco'),
  FormQuestionOption(id: 'muito', label: 'Muito'),
];

/// Pacote default RF0012–RF0015 (+ incidentes de saúde).
///
/// Flags alinhadas a `docs/requisitos/formularios-configuraveis.md`.
List<DefaultFormQuestion> defaultFormQuestionsPackage() {
  return const [
    // ── RF0012 Atividades ─────────────────────────────────────────────
    DefaultFormQuestion(
      seedKey: 'rf0012.atividade',
      prompt: 'Atividade realizada?',
      kind: FormQuestionKind.choice,
      options: _simNao,
      defaultOptionId: 'sim',
      flags: FormQuestionFlags(duranteDia: true),
      sortIndex: 0,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0012.descricao',
      prompt: 'Descrição da atividade',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, optional: true),
      sortIndex: 1,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0012.horario',
      prompt: 'Horário da atividade',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, optional: true),
      sortIndex: 2,
    ),

    // ── RF0013 Alimentação ────────────────────────────────────────────
    DefaultFormQuestion(
      seedKey: 'rf0013.comeu',
      prompt: 'Comeu?',
      kind: FormQuestionKind.choice,
      options: _comeu,
      defaultOptionId: 'bem',
      flags: FormQuestionFlags(duranteDia: true, saida: true),
      sortIndex: 10,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0013.tipo_refeicao',
      prompt: 'Tipo de refeição',
      kind: FormQuestionKind.choiceOther,
      options: _tipoRefeicao,
      defaultOptionId: 'almoco',
      flags: FormQuestionFlags(duranteDia: true),
      sortIndex: 11,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0013.horario',
      prompt: 'Horário da refeição',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, optional: true),
      sortIndex: 12,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0013.observacao',
      prompt: 'Observação da alimentação',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, saida: true, optional: true),
      sortIndex: 13,
    ),

    // ── RF0014 Sono / descanso ────────────────────────────────────────
    DefaultFormQuestion(
      seedKey: 'rf0014.descansou',
      prompt: 'Descansou?',
      kind: FormQuestionKind.choice,
      options: _dormiu,
      defaultOptionId: 'cochilou',
      flags: FormQuestionFlags(duranteDia: true, saida: true),
      sortIndex: 20,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0014.inicio',
      prompt: 'Início do descanso',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, optional: true),
      sortIndex: 21,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0014.fim',
      prompt: 'Fim do descanso',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, optional: true),
      sortIndex: 22,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0014.observacao',
      prompt: 'Observação do sono',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, saida: true, optional: true),
      sortIndex: 23,
    ),

    // ── RF0015 Ocorrências (rotina / parecer) ─────────────────────────
    DefaultFormQuestion(
      seedKey: 'rf0015.comportamento',
      prompt: 'Comportamento?',
      kind: FormQuestionKind.choice,
      options: _comportamento,
      defaultOptionId: 'tranquilo',
      flags: FormQuestionFlags(duranteDia: true, saida: true),
      sortIndex: 30,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0015.humor',
      prompt: 'Humor geral?',
      kind: FormQuestionKind.choice,
      options: _humor,
      defaultOptionId: 'contente',
      flags: FormQuestionFlags(duranteDia: true, saida: true),
      sortIndex: 31,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0015.chorou',
      prompt: 'Chorou?',
      kind: FormQuestionKind.choice,
      options: _chorou,
      defaultOptionId: 'nao',
      flags: FormQuestionFlags(duranteDia: true, saida: true),
      sortIndex: 32,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0015.evacuacoes',
      prompt: 'Evacuações / necessidades?',
      kind: FormQuestionKind.choice,
      options: _evacuacoes,
      defaultOptionId: 'normal',
      flags: FormQuestionFlags(duranteDia: true, saida: true),
      sortIndex: 33,
    ),
    DefaultFormQuestion(
      seedKey: 'rf0015.observacao',
      prompt: 'Observação da ocorrência',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, optional: true),
      sortIndex: 34,
    ),

    // ── Incidentes de saúde ───────────────────────────────────────────
    DefaultFormQuestion(
      seedKey: 'incident.saude',
      prompt: 'Incidente de saúde?',
      kind: FormQuestionKind.choice,
      options: _simNao,
      defaultOptionId: 'nao',
      flags: FormQuestionFlags(duranteDia: true, incident: true),
      sortIndex: 40,
    ),
    DefaultFormQuestion(
      seedKey: 'incident.descricao',
      prompt: 'Descrição do incidente',
      kind: FormQuestionKind.text,
      flags: FormQuestionFlags(duranteDia: true, incident: true, optional: true),
      sortIndex: 41,
    ),
    DefaultFormQuestion(
      seedKey: 'incident.anexo',
      prompt: 'Anexo do incidente (imagem)',
      kind: FormQuestionKind.image,
      flags: FormQuestionFlags(duranteDia: true, incident: true, optional: true),
      sortIndex: 42,
    ),
  ];
}

/// Todos os `seedKey` do pacote default (úteis em testes / idempotência).
Set<String> defaultFormQuestionSeedKeys() =>
    defaultFormQuestionsPackage().map((q) => q.seedKey).toSet();
