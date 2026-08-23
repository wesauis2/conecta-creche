import 'package:flutter/material.dart';

class BootstrapErrorScreen extends StatelessWidget {
  const BootstrapErrorScreen({
    super.key,
    required this.error,
  });

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conecta Creche')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Falha ao inicializar Firebase',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SelectableText(error.toString()),
          ],
        ),
      ),
    );
  }
}
