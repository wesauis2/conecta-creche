import 'package:flutter/material.dart';

import '../mural/foto_placeholder.dart';
import '../mural/mural_repository.dart';
import '../mural/post_mural.dart';
import 'mural_post_form_screen.dart';

/// Mural da creche: feed com avisos, lembretes e fotos.
/// Responsáveis só leem; equipe (`podePublicar`) também publica.
class MuralScreen extends StatefulWidget {
  const MuralScreen({
    super.key,
    this.podePublicar = false,
    this.mostrarAppBar = true,
    this.saudacao,
    this.autorNome = 'Equipe da creche',
    this.autorCargo = 'Equipe',
  });

  final bool podePublicar;
  final bool mostrarAppBar;
  final String? saudacao;
  final String autorNome;
  final String autorCargo;

  @override
  State<MuralScreen> createState() => _MuralScreenState();
}

class _MuralScreenState extends State<MuralScreen> {
  final MuralRepository _repository = MuralRepository();
  late List<PostMural> _posts;
  TipoPost? _filtro;

  @override
  void initState() {
    super.initState();
    _posts = _repository.listar();
  }

  List<PostMural> get _visiveis => _filtro == null
      ? _posts
      : _posts.where((p) => p.tipo == _filtro).toList();

  Future<void> _atualizar() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _posts = _repository.listar());
  }

  Future<void> _novaPublicacao() async {
    final novo = await Navigator.of(context).push<PostMural>(
      MaterialPageRoute<PostMural>(
        builder: (_) => MuralPostFormScreen(
          autor: widget.autorNome,
          cargo: widget.autorCargo,
        ),
      ),
    );
    if (novo == null) return;
    await _repository.publicar(novo);
    if (!mounted) return;
    setState(() => _posts = _repository.listar());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Publicado no mural (simulação — ainda não enviado às famílias).',
        ),
      ),
    );
  }

  Widget _chip(String label, TipoPost? tipo) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filtro == tipo,
        onSelected: (_) => setState(() => _filtro = tipo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiveis = _visiveis;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.mostrarAppBar ? AppBar(title: const Text('Mural')) : null,
      body: RefreshIndicator(
        onRefresh: _atualizar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            if (widget.saudacao != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.saudacao!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Novidades da creche para você e sua família.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('Tudo', null),
                  for (final tipo in TipoPost.values) _chip(tipo.label, tipo),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (visiveis.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.dashboard_outlined,
                        size: 56, color: scheme.outline),
                    const SizedBox(height: 12),
                    const Text('Nenhuma publicação por aqui ainda.'),
                  ],
                ),
              )
            else
              for (final post in visiveis)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PostCard(
                    key: ValueKey(post.id),
                    post: post,
                    mostrarVisualizacoes: widget.podePublicar,
                  ),
                ),
          ],
        ),
      ),
      floatingActionButton: widget.podePublicar
          ? FloatingActionButton.extended(
              onPressed: _novaPublicacao,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Nova publicação'),
            )
          : null,
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({
    super.key,
    required this.post,
    required this.mostrarVisualizacoes,
  });

  final PostMural post;
  final bool mostrarVisualizacoes;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _curtido = false;
  bool _ciente = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.fixado)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.push_pin, size: 16, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Fixado',
                      style: textTheme.labelMedium
                          ?.copyWith(color: scheme.primary),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    iniciaisDe(post.autor),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.autor,
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${post.cargo} · ${post.quando}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _TipoChip(tipo: post.tipo),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.titulo,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.groups_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  post.turma,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.texto),
            if (post.fotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FotosGrid(
                fotos: post.fotos,
                onTap: (index) => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        _FotoViewer(fotos: post.fotos, inicial: index),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _curtido = !_curtido),
                  icon: Icon(
                    _curtido ? Icons.favorite : Icons.favorite_border,
                    color: _curtido ? Colors.red.shade400 : null,
                  ),
                  label: Text('${post.curtidas + (_curtido ? 1 : 0)}'),
                ),
                const Spacer(),
                if (widget.mostrarVisualizacoes)
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Visto por ${post.visualizacoes} famílias',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  )
                else if (post.tipo != TipoPost.foto)
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _ciente = !_ciente),
                    icon: Icon(_ciente
                        ? Icons.check_circle
                        : Icons.check_circle_outline),
                    label: Text(_ciente ? 'Ciente' : 'Marcar ciente'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TipoChip extends StatelessWidget {
  const _TipoChip({required this.tipo});

  final TipoPost tipo;

  @override
  Widget build(BuildContext context) {
    final cor = tipo.cor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tipo.icone, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(
            tipo.label,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FotosGrid extends StatelessWidget {
  const _FotosGrid({required this.fotos, required this.onTap});

  final List<FotoMural> fotos;
  final void Function(int index) onTap;

  Widget _tile(int i, {String? sobreposicao}) {
    return GestureDetector(
      onTap: () => onTap(i),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FotoPlaceholder(foto: fotos[i]),
            if (sobreposicao != null)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Text(
                  sobreposicao,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = fotos.length;
    const gap = SizedBox(width: 4, height: 4);

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: n == 1
          ? _tile(0)
          : Row(
              children: [
                Expanded(child: _tile(0)),
                gap,
                Expanded(
                  child: n == 2
                      ? _tile(1)
                      : Column(
                          children: [
                            Expanded(child: _tile(1)),
                            gap,
                            Expanded(
                              child: _tile(
                                2,
                                sobreposicao: n > 3 ? '+${n - 3}' : null,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _FotoViewer extends StatefulWidget {
  const _FotoViewer({required this.fotos, required this.inicial});

  final List<FotoMural> fotos;
  final int inicial;

  @override
  State<_FotoViewer> createState() => _FotoViewerState();
}

class _FotoViewerState extends State<_FotoViewer> {
  late final PageController _controller;
  late int _atual;

  @override
  void initState() {
    super.initState();
    _atual = widget.inicial;
    _controller = PageController(initialPage: widget.inicial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_atual + 1} / ${widget.fotos.length}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.fotos.length,
              onPageChanged: (i) => setState(() => _atual = i),
              itemBuilder: (context, i) => Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: FotoPlaceholder(foto: widget.fotos[i], iconSize: 96),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Text(
              widget.fotos[_atual].legenda,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
