import 'package:flutter/material.dart';

import '../responsaveis/responsavel.dart';
import '../responsaveis/responsavel_repository.dart';

class ResponsavelFormScreen extends StatefulWidget {
  const ResponsavelFormScreen({super.key, this.existente});

  /// Quando presente, o formulário abre em modo de edição.
  final Responsavel? existente;

  @override
  State<ResponsavelFormScreen> createState() => _ResponsavelFormScreenState();
}

class _ResponsavelFormScreenState extends State<ResponsavelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _telefoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _observacoesController;

  late String _parentesco;
  late ResponsavelStatus _status;
  late Set<String> _criancasSelecionadas;

  bool _salvando = false;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final existente = widget.existente;
    _nomeController = TextEditingController(text: existente?.nome ?? '');
    _telefoneController =
        TextEditingController(text: existente?.telefone ?? '');
    _emailController = TextEditingController(text: existente?.email ?? '');
    _observacoesController =
        TextEditingController(text: existente?.observacoes ?? '');
    _parentesco = existente?.parentesco ?? parentescos.first;
    _status = existente?.status ?? ResponsavelStatus.pendente;
    _criancasSelecionadas =
        existente?.criancas.map((c) => c.id).toSet() ?? <String>{};
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final criancas = ResponsavelRepository.criancasDisponiveis
        .where((c) => _criancasSelecionadas.contains(c.id))
        .toList();

    final responsavel = Responsavel(
      id: widget.existente?.id ??
          'r_novo_${DateTime.now().microsecondsSinceEpoch}',
      nome: _nomeController.text.trim(),
      parentesco: _parentesco,
      telefone: _telefoneController.text.trim(),
      email: _emailController.text.trim(),
      status: _status,
      criancas: criancas,
      observacoes: _observacoesController.text.trim().isEmpty
          ? null
          : _observacoesController.text.trim(),
    );

    // Simula latência de rede; nada é persistido de fato ainda.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() => _salvando = false);
    Navigator.of(context).pop(responsavel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar responsável' : 'Novo responsável'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nomeController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Informe o nome do responsável.'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _parentesco,
              decoration: const InputDecoration(
                labelText: 'Parentesco / vínculo',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final parentesco in parentescos)
                  DropdownMenuItem(value: parentesco, child: Text(parentesco)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _parentesco = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone / WhatsApp',
                hintText: '(51) 90000-0000',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Informe um telefone de contato.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe um e-mail de contato.';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Informe um e-mail válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ResponsavelStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status do vínculo',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final status in ResponsavelStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Crianças vinculadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Selecione uma ou mais crianças matriculadas.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final crianca in ResponsavelRepository.criancasDisponiveis)
                  FilterChip(
                    label: Text('${crianca.nome} · ${crianca.turma}'),
                    selected: _criancasSelecionadas.contains(crianca.id),
                    onSelected: (selecionado) {
                      setState(() {
                        if (selecionado) {
                          _criancasSelecionadas.add(crianca.id);
                        } else {
                          _criancasSelecionadas.remove(crianca.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _observacoesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_editando ? 'Salvar alterações' : 'Cadastrar responsável'),
            ),
          ],
        ),
      ),
    );
  }
}
