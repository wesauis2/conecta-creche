import 'responsavel.dart';

/// Repositório apenas de interface (mock): mantém uma lista em memória
/// para a tela reagir a adições/edições durante a demonstração, sem
/// nenhuma integração real com Firestore ainda.
class ResponsavelRepository {
  ResponsavelRepository() : _itens = List<Responsavel>.from(_dadosIniciais);

  final List<Responsavel> _itens;

  static const CriancaRef _alice =
      CriancaRef(id: 'c1', nome: 'Alice Ferreira', turma: 'Berçário');
  static const CriancaRef _bento =
      CriancaRef(id: 'c2', nome: 'Bento Ferreira', turma: 'Maternal I');
  static const CriancaRef _davi =
      CriancaRef(id: 'c3', nome: 'Davi Souza', turma: 'Maternal II');
  static const CriancaRef _helena =
      CriancaRef(id: 'c4', nome: 'Helena Costa', turma: 'Jardim I');
  static const CriancaRef _igor =
      CriancaRef(id: 'c5', nome: 'Igor Martins', turma: 'Jardim II');
  static const CriancaRef _laura =
      CriancaRef(id: 'c6', nome: 'Laura Martins', turma: 'Jardim II');
  static const CriancaRef _miguel =
      CriancaRef(id: 'c7', nome: 'Miguel Rocha', turma: 'Berçário');

  static const List<CriancaRef> criancasDisponiveis = <CriancaRef>[
    _alice,
    _bento,
    _davi,
    _helena,
    _igor,
    _laura,
    _miguel,
  ];

  static const List<Responsavel> _dadosIniciais = <Responsavel>[
    Responsavel(
      id: 'r1',
      nome: 'Camila Ferreira',
      parentesco: 'Mãe',
      telefone: '(51) 99811-2233',
      email: 'camila.ferreira@email.com',
      status: ResponsavelStatus.ativo,
      criancas: [_alice, _bento],
      observacoes: 'Busca as crianças às 17h30, às terças e quintas.',
    ),
    Responsavel(
      id: 'r2',
      nome: 'Rodrigo Souza',
      parentesco: 'Pai',
      telefone: '(51) 99722-4455',
      email: 'rodrigo.souza@email.com',
      status: ResponsavelStatus.ativo,
      criancas: [_davi],
    ),
    Responsavel(
      id: 'r3',
      nome: 'Beatriz Costa',
      parentesco: 'Mãe',
      telefone: '(51) 99633-5566',
      email: 'bia.costa@email.com',
      status: ResponsavelStatus.pendente,
      criancas: [_helena],
      observacoes: 'Aguardando confirmação de documento pela gestão.',
    ),
    Responsavel(
      id: 'r4',
      nome: 'Eduardo Martins',
      parentesco: 'Pai',
      telefone: '(51) 99544-6677',
      email: 'eduardo.martins@email.com',
      status: ResponsavelStatus.ativo,
      criancas: [_igor, _laura],
    ),
    Responsavel(
      id: 'r5',
      nome: 'Sandra Martins',
      parentesco: 'Avó',
      telefone: '(51) 99455-7788',
      email: 'sandra.martins@email.com',
      status: ResponsavelStatus.ativo,
      criancas: [_igor, _laura],
      observacoes: 'Segunda responsável autorizada a buscar (Igor e Laura).',
    ),
    Responsavel(
      id: 'r6',
      nome: 'Patrícia Rocha',
      parentesco: 'Mãe',
      telefone: '(51) 99366-8899',
      email: 'patricia.rocha@email.com',
      status: ResponsavelStatus.inativo,
      criancas: [_miguel],
      observacoes:
          'Criança transferida em 06/2026; vínculo mantido só para histórico.',
    ),
  ];

  List<Responsavel> listar() => List<Responsavel>.unmodifiable(_itens);

  /// Simula uma gravação: apenas atualiza a lista em memória do processo
  /// atual. Não persiste em Firestore nem em disco.
  Future<void> salvar(Responsavel responsavel) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final index = _itens.indexWhere((item) => item.id == responsavel.id);
    if (index == -1) {
      _itens.add(responsavel);
    } else {
      _itens[index] = responsavel;
    }
  }

  Future<void> remover(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _itens.removeWhere((item) => item.id == id);
  }
}
