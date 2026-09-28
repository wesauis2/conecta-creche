// Entrypoint só para desenvolvimento: abre direto a tela de Responsáveis,
// sem passar por Firebase, Google Sign-In ou papéis de usuário.
//
// Rodar (mais rápido, sem emulador Android):
//   flutter run -d chrome -t lib/dev/preview_responsaveis.dart
//
// Rodar num emulador/celular Android já conectado:
//   flutter run -t lib/dev/preview_responsaveis.dart
//
// Não faz parte do app final — apenas uma porta de entrada auxiliar
// para testar a interface durante o desenvolvimento.
import 'package:flutter/material.dart';

import '../screens/responsaveis_list_screen.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conecta Creche — Preview Responsáveis',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const ResponsaveisListScreen(),
    );
  }
}
