/// Tipo de resposta da pergunta do formulário configurável.
/// Persistido em Firestore como o `name` (exceto [choiceOther] → `choice_other`).
enum FormQuestionKind {
  choice,
  text,
  image,
  audio,
  video,
  choiceOther;

  String get firestoreValue => switch (this) {
        FormQuestionKind.choiceOther => 'choice_other',
        _ => name,
      };

  static FormQuestionKind fromFirestore(String? value) {
    if (value == 'choice_other') {
      return FormQuestionKind.choiceOther;
    }
    return FormQuestionKind.values.firstWhere(
      (k) => k.name == value,
      orElse: () => FormQuestionKind.text,
    );
  }

  /// Rótulo curto pt-BR para badges na lista de gestão.
  String get badgeLabel => switch (this) {
        FormQuestionKind.choice => 'Opções',
        FormQuestionKind.choiceOther => 'Opções+outra',
        FormQuestionKind.text => 'Texto',
        FormQuestionKind.image => 'Imagem',
        FormQuestionKind.audio => 'Áudio',
        FormQuestionKind.video => 'Vídeo',
      };
}

/// Opção de escolha (`options[]` em `form_questions`).
class FormQuestionOption {
  const FormQuestionOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
      };

  factory FormQuestionOption.fromMap(Map<String, dynamic> map) {
    return FormQuestionOption(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormQuestionOption && id == other.id && label == other.label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Flags de UX / visibilidade. Ver `docs/requisitos/formularios-configuraveis.md`.
class FormQuestionFlags {
  const FormQuestionFlags({
    this.duranteDia = false,
    this.saida = false,
    this.oculta = false,
    this.incident = false,
    this.optional = false,
  });

  final bool duranteDia;
  final bool saida;
  final bool oculta;
  final bool incident;
  final bool optional;

  /// Opcional explícita: sem gesto do cuidador **não** grava valor
  /// (default visual ≠ valor persistido).
  bool shouldPersistAnswer({required bool explicitGesture}) {
    if (optional && !explicitGesture) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
        'durante_dia': duranteDia,
        'saida': saida,
        'oculta': oculta,
        'incident': incident,
        'optional': optional,
      };

  factory FormQuestionFlags.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FormQuestionFlags();
    }
    return FormQuestionFlags(
      duranteDia: map['durante_dia'] as bool? ?? false,
      saida: map['saida'] as bool? ?? false,
      oculta: map['oculta'] as bool? ?? false,
      incident: map['incident'] as bool? ?? false,
      optional: map['optional'] as bool? ?? false,
    );
  }

  FormQuestionFlags copyWith({
    bool? duranteDia,
    bool? saida,
    bool? oculta,
    bool? incident,
    bool? optional,
  }) {
    return FormQuestionFlags(
      duranteDia: duranteDia ?? this.duranteDia,
      saida: saida ?? this.saida,
      oculta: oculta ?? this.oculta,
      incident: incident ?? this.incident,
      optional: optional ?? this.optional,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormQuestionFlags &&
          duranteDia == other.duranteDia &&
          saida == other.saida &&
          oculta == other.oculta &&
          incident == other.incident &&
          optional == other.optional;

  @override
  int get hashCode =>
      Object.hash(duranteDia, saida, oculta, incident, optional);
}

/// Filtros da tela de config que simulam a visão do cuidador
/// (lista única; views filtradas — não bancos separados).
enum FormCaregiverViewFilter {
  todas,
  duranteDia,
  saida,
  ocultas,
  incidentes,
  opcionais;

  String get label => switch (this) {
        FormCaregiverViewFilter.todas => 'Todas',
        FormCaregiverViewFilter.duranteDia => 'Durante o dia',
        FormCaregiverViewFilter.saida => 'Saída',
        FormCaregiverViewFilter.ocultas => 'Ocultas',
        FormCaregiverViewFilter.incidentes => 'Incidentes',
        FormCaregiverViewFilter.opcionais => 'Opcionais',
      };
}

/// Pergunta do template em `form_questions/{id}`.
/// Ver CONTEXT.md "Formulário configurável".
class FormQuestion {
  const FormQuestion({
    required this.id,
    required this.prompt,
    required this.kind,
    required this.options,
    this.defaultOptionId,
    required this.flags,
    required this.sortIndex,
    required this.active,
    this.seedKey,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String id;
  final String prompt;
  final FormQuestionKind kind;
  final List<FormQuestionOption> options;
  final String? defaultOptionId;
  final FormQuestionFlags flags;
  final int sortIndex;
  final bool active;

  /// Chave estável do pacote default (`docs/requisitos/formularios-configuraveis.md`).
  /// Idempotência do seed sem `--replace`.
  final String? seedKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  /// Snapshot estável para embutir em answers (histórico independente do template).
  Map<String, dynamic> toSnapshotMap() => {
        'id': id,
        'prompt': prompt,
        'kind': kind.firestoreValue,
        'options': options.map((o) => o.toMap()).toList(),
        'defaultOptionId': defaultOptionId,
      };

  /// True se a pergunta entra na view filtrada do cuidador.
  bool matchesCaregiverView(FormCaregiverViewFilter filter) {
    return switch (filter) {
      FormCaregiverViewFilter.todas => true,
      // Lista curta do dia: durante_dia e não só ocultas.
      FormCaregiverViewFilter.duranteDia => flags.duranteDia && !flags.oculta,
      FormCaregiverViewFilter.saida => flags.saida,
      FormCaregiverViewFilter.ocultas => flags.oculta,
      FormCaregiverViewFilter.incidentes => flags.incident,
      FormCaregiverViewFilter.opcionais => flags.optional,
    };
  }

  factory FormQuestion.fromFirestore(String id, Map<String, dynamic> data) {
    final rawOptions = data['options'];
    final options = <FormQuestionOption>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map<String, dynamic>) {
          options.add(FormQuestionOption.fromMap(item));
        } else if (item is Map) {
          options.add(
            FormQuestionOption.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final flagsRaw = data['flags'];
    final flagsMap = flagsRaw is Map<String, dynamic>
        ? flagsRaw
        : flagsRaw is Map
            ? Map<String, dynamic>.from(flagsRaw)
            : null;

    return FormQuestion(
      id: id,
      prompt: data['prompt'] as String? ?? '',
      kind: FormQuestionKind.fromFirestore(data['kind'] as String?),
      options: options,
      defaultOptionId: data['defaultOptionId'] as String?,
      flags: FormQuestionFlags.fromMap(flagsMap),
      sortIndex: (data['sortIndex'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
      seedKey: data['seedKey'] as String?,
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
      createdBy: data['createdBy'] as String?,
      updatedBy: data['updatedBy'] as String?,
    );
  }
}

/// Aceita `DateTime` ou Timestamp-like (`toDate()`) sem depender de cloud_firestore
/// neste arquivo (permite `dart run` do seed sem `dart:ui`).
DateTime? _readDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    final dynamic dyn = value;
    final converted = dyn.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return null;
}
