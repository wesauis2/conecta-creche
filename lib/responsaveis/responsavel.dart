/// Status de vínculo do responsável com a creche.
enum ResponsavelStatus { ativo, pendente, inativo }

extension ResponsavelStatusLabel on ResponsavelStatus {
  String get label {
    switch (this) {
      case ResponsavelStatus.ativo:
        return 'Ativo';
      case ResponsavelStatus.pendente:
        return 'Pendente';
      case ResponsavelStatus.inativo:
        return 'Inativo';
    }
  }
}

/// Grau de parentesco/vínculo do responsável com a criança.
const List<String> parentescos = <String>[
  'Mãe',
  'Pai',
  'Avó',
  'Avô',
  'Tio(a)',
  'Responsável legal',
  'Outro',
];

/// Referência leve a uma criança matriculada, usada para vincular
/// responsáveis. Não é o cadastro completo de crianças (fora do escopo).
class CriancaRef {
  const CriancaRef({
    required this.id,
    required this.nome,
    required this.turma,
  });

  final String id;
  final String nome;
  final String turma;
}

class Responsavel {
  const Responsavel({
    required this.id,
    required this.nome,
    required this.parentesco,
    required this.telefone,
    required this.email,
    required this.status,
    this.criancas = const <CriancaRef>[],
    this.observacoes,
  });

  final String id;
  final String nome;
  final String parentesco;
  final String telefone;
  final String email;
  final ResponsavelStatus status;
  final List<CriancaRef> criancas;
  final String? observacoes;

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  Responsavel copyWith({
    String? nome,
    String? parentesco,
    String? telefone,
    String? email,
    ResponsavelStatus? status,
    List<CriancaRef>? criancas,
    String? observacoes,
  }) {
    return Responsavel(
      id: id,
      nome: nome ?? this.nome,
      parentesco: parentesco ?? this.parentesco,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      status: status ?? this.status,
      criancas: criancas ?? this.criancas,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}
