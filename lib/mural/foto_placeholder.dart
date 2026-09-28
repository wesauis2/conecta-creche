import 'package:flutter/material.dart';

import 'post_mural.dart';

/// Desenha uma "foto" ilustrativa (gradiente + ícone) enquanto não há
/// upload/armazenamento real de imagens.
class FotoPlaceholder extends StatelessWidget {
  const FotoPlaceholder({super.key, required this.foto, this.iconSize = 36});

  final FotoMural foto;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [foto.cor, Color.lerp(foto.cor, Colors.black, 0.25)!],
        ),
      ),
      child: Center(
        child: Icon(
          foto.icone,
          size: iconSize,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
