// Entrypoint só para desenvolvimento: abre direto o Mural em memória.
// Use o botão do topo para alternar entre a visão do responsável e da gestão.
//
//   flutter run -d chrome -t lib/dev/preview_mural.dart
//   flutter run -t lib/dev/preview_mural.dart
import 'package:flutter/material.dart';

import '../mural/mural_post.dart';
import '../mural/mural_repository.dart';
import '../screens/mural_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = MemoryMuralRepository();
  final now = DateTime.now();
  await repository.createPost(
    title: 'Reunião de pais',
    body: 'Sexta às 18h30 na sala multiuso. Sua presença é importante!',
    kind: MuralPostKind.comunicado,
    createdBy: 'preview',
    releasedAt: now.subtract(const Duration(days: 1)),
    effectiveAt: now.subtract(const Duration(days: 1)),
  );
  await repository.createPost(
    title: 'Confraternização dia da criança',
    body: 'Tragam fantasia leve. Haverá lanche coletivo.',
    kind: MuralPostKind.evento,
    createdBy: 'preview',
    releasedAt: now.subtract(const Duration(days: 10)),
    effectiveAt: now.add(const Duration(days: 20)),
    location: 'Parque municipal',
    scheduleText: '9h às 11h30',
  );
  runApp(_PreviewApp(repository: repository));
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp({required this.repository});

  final MemoryMuralRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conecta Creche — Preview Mural',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: _PreviewHome(repository: repository),
    );
  }
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome({required this.repository});

  final MemoryMuralRepository repository;

  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  bool _gestao = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_gestao ? 'Visão: gestão' : 'Visão: responsável'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _gestao = !_gestao),
            icon: const Icon(Icons.swap_horiz),
            label: Text(_gestao ? 'Ver como responsável' : 'Ver como gestão'),
          ),
        ],
      ),
      body: MuralScreen(
        key: ValueKey(_gestao),
        repository: widget.repository,
        authorUid: 'preview-uid',
        podePublicar: _gestao,
        mostrarAppBar: false,
        saudacao: _gestao ? null : 'Olá, Camila!',
      ),
    );
  }
}
