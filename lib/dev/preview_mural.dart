// Entrypoint só para desenvolvimento: abre direto o Mural, sem Firebase/login.
// Use o botão do topo para alternar entre a visão do responsável e da equipe.
//
//   flutter run -d chrome -t lib/dev/preview_mural.dart
//   flutter run -t lib/dev/preview_mural.dart   (celular/emulador Android)
import 'package:flutter/material.dart';

import '../screens/mural_screen.dart';

void main() {
  runApp(const _PreviewApp());
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conecta Creche — Preview Mural',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const _PreviewHome(),
    );
  }
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome();

  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  bool _equipe = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_equipe ? 'Visão: equipe' : 'Visão: responsável'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _equipe = !_equipe),
            icon: const Icon(Icons.swap_horiz),
            label: Text(_equipe ? 'Ver como responsável' : 'Ver como equipe'),
          ),
        ],
      ),
      body: MuralScreen(
        key: ValueKey(_equipe),
        podePublicar: _equipe,
        mostrarAppBar: false,
        saudacao: _equipe ? null : 'Olá, Camila!',
        autorNome: 'Juliana Reis',
        autorCargo: 'Cuidadora',
      ),
    );
  }
}
