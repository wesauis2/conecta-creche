import 'package:flutter/material.dart';

import '../responsaveis/responsavel.dart';
import 'responsavel_form_screen.dart';

class ResponsavelDetailScreen extends StatefulWidget {
  const ResponsavelDetailScreen({super.key, required this.responsavel});

  final Responsavel responsavel;

  @override
  State<ResponsavelDetailScreen> createState() =>
      _ResponsavelDetailScreenState();
}

class _ResponsavelDetailScreenState extends State<ResponsavelDetailScreen> {
  late Responsavel _responsavel;

  @override
  void initState() {
    super.initState();
    _responsavel = widget.responsavel;
  }

  void _acaoSimulada(String rotulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$rotulo (ação simulada nesta versão).')),
    );
  }

  Future<void> _editar() async {
    final atualizado = await Navigator.of(context).push<Responsavel>(
      MaterialPageRoute<Responsavel>(
        builder: (_) => ResponsavelFormScreen(existente: _responsavel),
      ),
    );
    if (atualizado != null) {
      setState(() => _responsavel = atualizado);
    }
  }

  void _confirmarRemocao() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover vínculo'),
        content: Text(
          'Remover ${_responsavel.nome} como responsável? '
          'Esta é apenas uma simulação de interface.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(_responsavel);
              _acaoSimulada('Vínculo removido');
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  Color _corStatus(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_responsavel.status) {
      case ResponsavelStatus.ativo:
        return Colors.green.shade600;
      case ResponsavelStatus.pendente:
        return Colors.orange.shade700;
      case ResponsavelStatus.inativo:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final corStatus = _corStatus(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsável'),
        actions: [
          IconButton(
            onPressed: _editar,
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    _responsavel.iniciais,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _responsavel.nome,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _responsavel.parentesco,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _responsavel.status.label,
                    style: TextStyle(
                      color: corStatus,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Contato', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: Text(_responsavel.telefone),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Abrir WhatsApp',
                    onPressed: () => _acaoSimulada(
                      'Abrindo conversa com ${_responsavel.nome}',
                    ),
                  ),
                  onTap: () => _acaoSimulada('Ligando para ${_responsavel.nome}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(_responsavel.email),
                  onTap: () => _acaoSimulada('Abrindo e-mail para ${_responsavel.nome}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Crianças vinculadas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_responsavel.criancas.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nenhuma criança vinculada a este responsável.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final crianca in _responsavel.criancas)
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.child_care),
                      ),
                      title: Text(crianca.nome),
                      subtitle: Text(crianca.turma),
                    ),
                ],
              ),
            ),
          if (_responsavel.observacoes != null &&
              _responsavel.observacoes!.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Observações', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_responsavel.observacoes!),
              ),
            ),
          ],
          const SizedBox(height: 32),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: _confirmarRemocao,
            icon: const Icon(Icons.link_off),
            label: const Text('Remover vínculo com a creche'),
          ),
        ],
      ),
    );
  }
}
