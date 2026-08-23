import 'package:flutter/material.dart';

class ConfigMissingScreen extends StatelessWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conecta Creche')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firebase não configurado',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Execute o wizard local para criar lib/firebase_options.dart '
              'e android/app/google-services.json (não versionados):',
            ),
            SizedBox(height: 8),
            SelectableText('./sh/firebase-setup.sh'),
            SizedBox(height: 12),
            Text('Referência: docs/credentials.md'),
          ],
        ),
      ),
    );
  }
}
