import 'package:flutter/material.dart';

import '../responsaveis/responsavel.dart';
import '../responsaveis/responsavel_repository.dart';
import 'responsavel_detail_screen.dart';
import 'responsavel_form_screen.dart';

class ResponsaveisListScreen extends StatefulWidget {
  const ResponsaveisListScreen({super.key});

  @override
  State<ResponsaveisListScreen> createState() =>
      _ResponsaveisListScreenState();
}

class _ResponsaveisListScreenState extends State<ResponsaveisListScreen> {
  final ResponsavelRepository _repository = ResponsavelRepository();
  final TextEditingController _searchController = TextEditingController();

  late List<Responsavel> _todos;
  String _busca = '';
  ResponsavelStatus? _filtroStatus;

  @override
  void initState() {
    super.initState();
    _todos = _repository.listar();
    _searchController.addListener(() {
      setState(() => _busca = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Responsavel> get _filtrados {
    return _todos.where((r) {
      final combinaBusca = _busca.isEmpty ||
          r.nome.toLowerCase().contains(_busca) ||
          r.criancas.any((c) => c.nome.toLowerCase().contains(_busca));
      final combinaStatus = _filtroStatus == null || r.status == _filtroStatus;
      return combinaBusca && combinaStatus;
    }).toList();
  }

  Future<void> _abrirFormulario({Responsavel? existente}) async {
    final resultado = await Navigator.of(context).push<Responsavel>(
      MaterialPageRoute<Responsavel>(
        builder: (_) => ResponsavelFormScreen(existente: existente),
      ),
    );
    if (resultado == null) return;

    setState(() {
      final index = _todos.indexWhere((r) => r.id == resultado.id);
      if (index == -1) {
        _todos = [..._todos, resultado];
      } else {
        _todos = [..._todos]..[index] = resultado;
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existente == null
              ? 'Responsável cadastrado (simulação — ainda não integrado ao Firestore).'
              : 'Responsável atualizado (simulação).',
        ),
      ),
    );
  }

  Future<void> _abrirDetalhe(Responsavel responsavel) async {
    final atualizado = await Navigator.of(context).push<Responsavel>(
      MaterialPageRoute<Responsavel>(
        builder: (_) => ResponsavelDetailScreen(responsavel: responsavel),
      ),
    );
    if (atualizado == null) return;
    setState(() {
      final index = _todos.indexWhere((r) => r.id == atualizado.id);
      if (index != -1) {
        _todos = [..._todos]..[index] = atualizado;
      }
    });
  }

  void _abrirFiltro() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar por status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _filtroStatus == null,
                      onSelected: (_) {
                        setState(() => _filtroStatus = null);
                        Navigator.of(context).pop();
                      },
                    ),
                    for (final status in ResponsavelStatus.values)
                      ChoiceChip(
                        label: Text(status.label),
                        selected: _filtroStatus == status,
                        onSelected: (_) {
                          setState(() => _filtroStatus = status);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final itens = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsáveis'),
        actions: [
          IconButton(
            onPressed: _abrirFiltro,
            tooltip: 'Filtrar',
            icon: Badge(
              isLabelVisible: _filtroStatus != null,
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por responsável ou criança',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                suffixIcon: _busca.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _searchController.clear,
                      ),
              ),
            ),
          ),
          Expanded(
            child: itens.isEmpty
                ? _EstadoVazio(temFiltro: _busca.isNotEmpty || _filtroStatus != null)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: itens.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final responsavel = itens[index];
                      return _ResponsavelCard(
                        responsavel: responsavel,
                        onTap: () => _abrirDetalhe(responsavel),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo responsável'),
      ),
    );
  }
}

class _ResponsavelCard extends StatelessWidget {
  const _ResponsavelCard({required this.responsavel, required this.onTap});

  final Responsavel responsavel;
  final VoidCallback onTap;

  Color _corStatus(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (responsavel.status) {
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
    final nomesCriancas = responsavel.criancas.map((c) => c.nome).join(', ');
    final corStatus = _corStatus(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  responsavel.iniciais,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            responsavel.nome,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: corStatus.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            responsavel.status.label,
                            style: TextStyle(
                              color: corStatus,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      responsavel.parentesco,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (nomesCriancas.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.child_care,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              nomesCriancas,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio({required this.temFiltro});

  final bool temFiltro;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              temFiltro ? Icons.search_off : Icons.people_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              temFiltro
                  ? 'Nenhum responsável encontrado para esse filtro.'
                  : 'Nenhum responsável cadastrado ainda.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
