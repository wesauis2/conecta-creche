import 'package:flutter/material.dart';

import 'post_mural.dart';

/// Repositório apenas de interface (mock): posts em memória, sem Firestore
/// nem Storage. Fotos são placeholders coloridos.
class MuralRepository {
  MuralRepository() : _itens = _dadosIniciais();

  final List<PostMural> _itens;

  static const List<FotoMural> fotosExemplo = <FotoMural>[
    FotoMural(
      legenda: 'Pintura com tinta guache',
      cor: Color(0xFFF06292),
      icone: Icons.palette,
    ),
    FotoMural(
      legenda: 'Hora da história',
      cor: Color(0xFF4DB6AC),
      icone: Icons.menu_book,
    ),
    FotoMural(
      legenda: 'Brincadeiras no parquinho',
      cor: Color(0xFF81C784),
      icone: Icons.park,
    ),
    FotoMural(
      legenda: 'Aniversariantes do mês',
      cor: Color(0xFFFFB74D),
      icone: Icons.cake,
    ),
    FotoMural(
      legenda: 'Roda de música',
      cor: Color(0xFF7986CB),
      icone: Icons.music_note,
    ),
    FotoMural(
      legenda: 'Hora do lanche',
      cor: Color(0xFFBA68C8),
      icone: Icons.restaurant,
    ),
  ];

  static List<PostMural> _dadosIniciais() {
    final agora = DateTime.now();
    return <PostMural>[
      PostMural(
        id: 'p1',
        tipo: TipoPost.lembrete,
        titulo: 'Reunião de pais — sexta, 18h30',
        texto: 'Vamos conversar sobre o planejamento do último trimestre e '
            'a festa de encerramento. Sua presença é muito importante!',
        autor: 'Helena Duarte',
        cargo: 'Direção',
        turma: 'Todas as turmas',
        criadoEm: agora.subtract(const Duration(days: 2)),
        fixado: true,
        curtidas: 12,
        visualizacoes: 41,
      ),
      PostMural(
        id: 'p2',
        tipo: TipoPost.foto,
        titulo: 'Tarde de pintura no Maternal II',
        texto: 'As crianças exploraram cores e texturas com tinta guache. '
            'Olha só quanta criatividade!',
        autor: 'Marina Prado',
        cargo: 'Professora',
        turma: 'Maternal II',
        criadoEm: agora.subtract(const Duration(hours: 2)),
        fotos: [fotosExemplo[0], fotosExemplo[4], fotosExemplo[3], fotosExemplo[5]],
        curtidas: 18,
        visualizacoes: 22,
      ),
      PostMural(
        id: 'p3',
        tipo: TipoPost.lembrete,
        titulo: 'Amanhã: passeio ao parque',
        texto: 'Enviar chapéu, protetor solar e garrafinha de água '
            'identificada. Saída às 9h, retorno às 11h30.',
        autor: 'Juliana Reis',
        cargo: 'Cuidadora',
        turma: 'Jardim I',
        criadoEm: agora.subtract(const Duration(hours: 5)),
        curtidas: 7,
        visualizacoes: 15,
      ),
      PostMural(
        id: 'p4',
        tipo: TipoPost.aviso,
        titulo: 'Recesso de 12 de outubro',
        texto: 'Não haverá aula na segunda-feira, 12/10 (feriado de Nossa '
            'Senhora Aparecida). Retornamos normalmente na terça.',
        autor: 'Helena Duarte',
        cargo: 'Direção',
        turma: 'Todas as turmas',
        criadoEm: agora.subtract(const Duration(days: 1, hours: 3)),
        curtidas: 9,
        visualizacoes: 38,
      ),
      PostMural(
        id: 'p5',
        tipo: TipoPost.foto,
        titulo: 'Hora da história no Berçário',
        texto: 'Livros sensoriais e muita curiosidade na roda de hoje.',
        autor: 'Carla Menezes',
        cargo: 'Cuidadora',
        turma: 'Berçário',
        criadoEm: agora.subtract(const Duration(days: 1, hours: 8)),
        fotos: [fotosExemplo[1], fotosExemplo[2]],
        curtidas: 24,
        visualizacoes: 17,
      ),
      PostMural(
        id: 'p6',
        tipo: TipoPost.aviso,
        titulo: 'Frio chegando: agasalho identificado',
        texto: 'Por favor, coloquem o nome nos casacos e cobertores das '
            'crianças para evitar trocas. Obrigada!',
        autor: 'Marina Prado',
        cargo: 'Professora',
        turma: 'Todas as turmas',
        criadoEm: agora.subtract(const Duration(days: 4)),
        curtidas: 5,
        visualizacoes: 36,
      ),
    ];
  }

  /// Fixados primeiro, depois do mais recente para o mais antigo.
  List<PostMural> listar() {
    final copia = List<PostMural>.from(_itens);
    copia.sort((a, b) {
      if (a.fixado != b.fixado) return a.fixado ? -1 : 1;
      return b.criadoEm.compareTo(a.criadoEm);
    });
    return copia;
  }

  /// Simula publicação: só altera a lista em memória.
  Future<void> publicar(PostMural post) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _itens.add(post);
  }
}
