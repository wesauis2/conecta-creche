import 'package:flutter/material.dart';

enum TipoPost { aviso, lembrete, foto }

extension TipoPostInfo on TipoPost {
  String get label => switch (this) {
        TipoPost.aviso => 'Aviso',
        TipoPost.lembrete => 'Lembrete',
        TipoPost.foto => 'Fotos',
      };

  IconData get icone => switch (this) {
        TipoPost.aviso => Icons.campaign_outlined,
        TipoPost.lembrete => Icons.alarm,
        TipoPost.foto => Icons.photo_library_outlined,
      };

  Color get cor => switch (this) {
        TipoPost.aviso => Colors.blue.shade600,
        TipoPost.lembrete => Colors.orange.shade700,
        TipoPost.foto => Colors.purple.shade400,
      };
}

const List<String> turmasMural = <String>[
  'Todas as turmas',
  'Berçário',
  'Maternal I',
  'Maternal II',
  'Jardim I',
  'Jardim II',
];

/// Foto ilustrativa (placeholder colorido). Nesta versão não há upload real.
class FotoMural {
  const FotoMural({
    required this.legenda,
    required this.cor,
    required this.icone,
  });

  final String legenda;
  final Color cor;
  final IconData icone;
}

class PostMural {
  const PostMural({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.texto,
    required this.autor,
    required this.cargo,
    required this.turma,
    required this.criadoEm,
    this.fixado = false,
    this.fotos = const <FotoMural>[],
    this.curtidas = 0,
    this.visualizacoes = 0,
  });

  final String id;
  final TipoPost tipo;
  final String titulo;
  final String texto;
  final String autor;
  final String cargo;
  final String turma;
  final DateTime criadoEm;
  final bool fixado;
  final List<FotoMural> fotos;
  final int curtidas;
  final int visualizacoes;

  String get quando {
    final diff = DateTime.now().difference(criadoEm);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours} h';
    if (diff.inHours < 48) return 'ontem';
    final dia = criadoEm.day.toString().padLeft(2, '0');
    final mes = criadoEm.month.toString().padLeft(2, '0');
    return '$dia/$mes';
  }
}

String iniciaisDe(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+'));
  if (partes.isEmpty || partes.first.isEmpty) return '?';
  final ultima = partes.length > 1 ? partes.last[0] : '';
  return (partes.first[0] + ultima).toUpperCase();
}
