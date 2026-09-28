import 'package:flutter/material.dart';

import '../mural/foto_placeholder.dart';
import '../mural/mural_repository.dart';
import '../mural/post_mural.dart';

/// Formulário de nova publicação no mural (só interface: as fotos são
/// ilustrativas e nada é enviado de fato).
class MuralPostFormScreen extends StatefulWidget {
  const MuralPostFormScreen({
    super.key,
    required this.autor,
    required this.cargo,
  });

  final String autor;
  final String cargo;

  @override
  State<MuralPostFormScreen> createState() => _MuralPostFormScreenState();
}

class _MuralPostFormScreenState extends State<MuralPostFormScreen> {
  static const int _maxFotos = 6;

  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _textoController = TextEditingController();

  TipoPost _tipo = TipoPost.aviso;
  String _turma = turmasMural.first;
  bool _fixado = false;
  bool _publicando = false;
  final List<FotoMural> _fotos = <FotoMural>[];

  @override
  void dispose() {
    _tituloController.dispose();
    _textoController.dispose();
    super.dispose();
  }

  void _adicionarFoto() {
    if (_fotos.length >= _maxFotos) return;
    setState(() {
      _fotos.add(
        MuralRepository.fotosExemplo[
            _fotos.length % MuralRepository.fotosExemplo.length],
      );
    });
  }

  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipo == TipoPost.foto && _fotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos uma foto.')),
      );
      return;
    }

    setState(() => _publicando = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.of(context).pop(
      PostMural(
        id: 'p_${DateTime.now().microsecondsSinceEpoch}',
        tipo: _tipo,
        titulo: _tituloController.text.trim(),
        texto: _textoController.text.trim(),
        autor: widget.autor,
        cargo: widget.cargo,
        turma: _turma,
        criadoEm: DateTime.now(),
        fixado: _fixado,
        fotos: List<FotoMural>.from(_fotos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova publicação')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<TipoPost>(
              showSelectedIcon: false,
              segments: [
                for (final tipo in TipoPost.values)
                  ButtonSegment<TipoPost>(
                    value: tipo,
                    icon: Icon(tipo.icone),
                    label: Text(tipo.label),
                  ),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _turma,
              decoration: const InputDecoration(
                labelText: 'Para quem?',
                prefixIcon: Icon(Icons.groups_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final turma in turmasMural)
                  DropdownMenuItem(value: turma, child: Text(turma)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _turma = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tituloController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe um título.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _textoController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escreva uma mensagem para as famílias.'
                  : null,
            ),
            const SizedBox(height: 24),
            Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Nesta versão as fotos são ilustrativas (sem upload real).',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _fotos.length; i++)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FotoPlaceholder(foto: _fotos[i], iconSize: 28),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => setState(() => _fotos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_fotos.length < _maxFotos)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _adicionarFoto,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined),
                          SizedBox(height: 4),
                          Text('Adicionar', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fixar no topo do mural'),
              subtitle: const Text('Use para avisos importantes.'),
              value: _fixado,
              onChanged: (v) => setState(() => _fixado = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _publicando ? null : _publicar,
              child: _publicando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publicar no mural'),
            ),
          ],
        ),
      ),
    );
  }
}
