/// Chorou? — SPEC v1 options, default "não".
enum ParecerChorou { nao, umPouco, muito }

/// pt-BR button-group label for [ParecerChorou], see CONTEXT.md "Parecer".
extension ParecerChorouLabel on ParecerChorou {
  String get label => switch (this) {
        ParecerChorou.nao => 'Não',
        ParecerChorou.umPouco => 'Um pouco',
        ParecerChorou.muito => 'Muito',
      };
}

/// Comportamento? — SPEC v1 options, default "tranquilo".
enum ParecerComportamento { tranquilo, agitado, precisouDeAtencao }

/// pt-BR button-group label for [ParecerComportamento].
extension ParecerComportamentoLabel on ParecerComportamento {
  String get label => switch (this) {
        ParecerComportamento.tranquilo => 'Tranquilo',
        ParecerComportamento.agitado => 'Agitado',
        ParecerComportamento.precisouDeAtencao => 'Precisou de atenção',
      };
}

/// Comeu? — SPEC v1 options, default "bem".
enum ParecerComeu { bem, parcial, pouco, nao }

/// pt-BR button-group label for [ParecerComeu].
extension ParecerComeuLabel on ParecerComeu {
  String get label => switch (this) {
        ParecerComeu.bem => 'Bem',
        ParecerComeu.parcial => 'Parcial',
        ParecerComeu.pouco => 'Pouco',
        ParecerComeu.nao => 'Não',
      };
}

/// Dormiu? — SPEC v1 options, default "cochilou".
enum ParecerDormiu { sim, cochilou, nao }

/// pt-BR button-group label for [ParecerDormiu].
extension ParecerDormiuLabel on ParecerDormiu {
  String get label => switch (this) {
        ParecerDormiu.sim => 'Sim',
        ParecerDormiu.cochilou => 'Cochilou',
        ParecerDormiu.nao => 'Não',
      };
}

/// Evacuações? — SPEC v1 options, default "normal".
enum ParecerEvacuacoes { normal, naoFez, atencao }

/// pt-BR button-group label for [ParecerEvacuacoes].
extension ParecerEvacuacoesLabel on ParecerEvacuacoes {
  String get label => switch (this) {
        ParecerEvacuacoes.normal => 'Normal',
        ParecerEvacuacoes.naoFez => 'Não fez',
        ParecerEvacuacoes.atencao => 'Atenção',
      };
}

/// Humor geral? — SPEC v1 options, default "contente".
enum ParecerHumor { contente, neutro, irritado }

/// pt-BR button-group label for [ParecerHumor].
extension ParecerHumorLabel on ParecerHumor {
  String get label => switch (this) {
        ParecerHumor.contente => 'Contente',
        ParecerHumor.neutro => 'Neutro',
        ParecerHumor.irritado => 'Irritado',
      };
}

/// Fixed quick-answer questionnaire filled at departure ("saída").
///
/// Each question is a closed set of button-group options (never a
/// dropdown), with the SPEC v1 default pre-selected. See CONTEXT.md
/// "Parecer" and SPEC.md "Further Notes".
class Parecer {
  const Parecer({
    this.chorou = ParecerChorou.nao,
    this.comportamento = ParecerComportamento.tranquilo,
    this.comeu = ParecerComeu.bem,
    this.dormiu = ParecerDormiu.cochilou,
    this.evacuacoes = ParecerEvacuacoes.normal,
    this.humor = ParecerHumor.contente,
  });

  final ParecerChorou chorou;
  final ParecerComportamento comportamento;
  final ParecerComeu comeu;
  final ParecerDormiu dormiu;
  final ParecerEvacuacoes evacuacoes;
  final ParecerHumor humor;

  Map<String, dynamic> toMap() => {
        'chorou': chorou.name,
        'comportamento': comportamento.name,
        'comeu': comeu.name,
        'dormiu': dormiu.name,
        'evacuacoes': evacuacoes.name,
        'humor': humor.name,
      };

  factory Parecer.fromMap(Map<String, dynamic> map) {
    return Parecer(
      chorou: _enumFromName(ParecerChorou.values, map['chorou'],
          ParecerChorou.nao),
      comportamento: _enumFromName(ParecerComportamento.values,
          map['comportamento'], ParecerComportamento.tranquilo),
      comeu:
          _enumFromName(ParecerComeu.values, map['comeu'], ParecerComeu.bem),
      dormiu: _enumFromName(
          ParecerDormiu.values, map['dormiu'], ParecerDormiu.cochilou),
      evacuacoes: _enumFromName(ParecerEvacuacoes.values, map['evacuacoes'],
          ParecerEvacuacoes.normal),
      humor: _enumFromName(
          ParecerHumor.values, map['humor'], ParecerHumor.contente),
    );
  }

  static T _enumFromName<T extends Enum>(
    List<T> values,
    Object? name,
    T fallback,
  ) {
    if (name is! String) {
      return fallback;
    }
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => fallback,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Parecer &&
      other.chorou == chorou &&
      other.comportamento == comportamento &&
      other.comeu == comeu &&
      other.dormiu == dormiu &&
      other.evacuacoes == evacuacoes &&
      other.humor == humor;

  @override
  int get hashCode =>
      Object.hash(chorou, comportamento, comeu, dormiu, evacuacoes, humor);

  @override
  String toString() => 'Parecer(${toMap()})';
}
