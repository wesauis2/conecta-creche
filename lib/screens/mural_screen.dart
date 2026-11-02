import 'package:flutter/material.dart';

import '../mural/mural_post.dart';
import '../mural/mural_repository.dart';
import 'mural_post_form_screen.dart';

/// Timeline do mural ordenada por efetividade. Gestão+ publica/edita;
/// demais papéis só leem itens já liberados.
class MuralScreen extends StatefulWidget {
  const MuralScreen({
    super.key,
    required this.repository,
    required this.authorUid,
    this.podePublicar = false,
    this.mostrarAppBar = true,
    this.saudacao,
  });

  final MuralPostsRepository repository;
  final String authorUid;
  final bool podePublicar;
  final bool mostrarAppBar;
  final String? saudacao;

  @override
  State<MuralScreen> createState() => _MuralScreenState();
}

class _MuralScreenState extends State<MuralScreen> {
  static const int _pageSize = 20;

  final List<MuralPost> _posts = <MuralPost>[];
  final Set<String> _expandedIds = <String>{};
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  MuralPostKind? _filtro;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final page = widget.podePublicar
          ? await _listForWriter(pageSize: _pageSize)
          : await widget.repository.listVisiblePosts(pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(page);
        _hasMore = page.length >= _pageSize;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<List<MuralPost>> _listForWriter({
    int pageSize = 20,
    DateTime? startAfterEffectiveAt,
    String? startAfterId,
  }) async {
    // Gestão vê agendados também; pagina no client como a lista visível.
    final all =
        await widget.repository.watchPosts(includeUnreleased: true).first;
    Iterable<MuralPost> page = all;
    if (startAfterEffectiveAt != null && startAfterId != null) {
      page = all.where((post) {
        final cmp = post.effectiveAt.compareTo(startAfterEffectiveAt);
        if (cmp != 0) return cmp < 0;
        return post.id.compareTo(startAfterId) < 0;
      });
    }
    return page.take(pageSize).toList(growable: false);
  }

  Future<void> _loadMore() async {
    if (_posts.isEmpty || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final last = _posts.last;
    try {
      final next = widget.podePublicar
          ? await _listForWriter(
              pageSize: _pageSize,
              startAfterEffectiveAt: last.effectiveAt,
              startAfterId: last.id,
            )
          : await widget.repository.listVisiblePosts(
              pageSize: _pageSize,
              startAfterEffectiveAt: last.effectiveAt,
              startAfterId: last.id,
            );
      if (!mounted) return;
      setState(() {
        _posts.addAll(next);
        _hasMore = next.length >= _pageSize;
        _loadingMore = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar mais: $error')),
      );
    }
  }

  Future<void> _novaPublicacao({MuralPost? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => MuralPostFormScreen(
          repository: widget.repository,
          authorUid: widget.authorUid,
          existing: existing,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Publicação salva no mural.'
                : 'Publicação atualizada.',
          ),
        ),
      );
      await _reload();
    }
  }

  List<MuralPost> get _visiveis {
    if (_filtro == null) return _posts;
    return _posts.where((p) => p.kind == _filtro).toList();
  }

  Widget _chip(String label, MuralPostKind? kind) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filtro == kind,
        onSelected: (_) => setState(() => _filtro = kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visiveis = _visiveis;

    return Scaffold(
      appBar: widget.mostrarAppBar ? AppBar(title: const Text('Mural')) : null,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('Não foi possível carregar o mural.\n$_error'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        child: const Text('Tentar de novo'),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: visiveis.length + 2 + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.saudacao != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.saudacao!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Novidades da creche para você e sua família.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
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
                                  for (final kind in MuralPostKind.values)
                                    _chip(kind.label, kind),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }

                      final postIndex = index - 1;
                      if (visiveis.isEmpty && postIndex == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              Icon(Icons.dashboard_outlined,
                                  size: 56, color: scheme.outline),
                              const SizedBox(height: 12),
                              const Text('Nenhuma publicação por aqui ainda.'),
                            ],
                          ),
                        );
                      }

                      if (postIndex >= visiveis.length) {
                        if (_loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      final post = visiveis[postIndex];
                      final expanded = _expandedIds.contains(post.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MuralPostTile(
                          key: ValueKey(post.id),
                          post: post,
                          expanded: expanded,
                          showUnreleasedBadge: widget.podePublicar &&
                              !post.isReleased(),
                          onToggle: () => setState(() {
                            if (expanded) {
                              _expandedIds.remove(post.id);
                            } else {
                              _expandedIds.add(post.id);
                            }
                          }),
                          onEdit: widget.podePublicar
                              ? () => _novaPublicacao(existing: post)
                              : null,
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: widget.podePublicar
          ? FloatingActionButton.extended(
              onPressed: () => _novaPublicacao(),
              icon: const Icon(Icons.post_add_outlined),
              label: const Text('Nova publicação'),
            )
          : null,
    );
  }
}

class _MuralPostTile extends StatelessWidget {
  const _MuralPostTile({
    super.key,
    required this.post,
    required this.expanded,
    required this.onToggle,
    this.onEdit,
    this.showUnreleasedBadge = false,
  });

  final MuralPost post;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;
  final bool showUnreleasedBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(post.kind.icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    post.kind.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMuralDate(post.effectiveAt),
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (showUnreleasedBadge) ...[
                const SizedBox(height: 8),
                Text(
                  'Agendado · libera em ${formatMuralDateTime(post.releasedAt)}',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.tertiary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                post.title,
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (!expanded) ...[
                const SizedBox(height: 4),
                Text(
                  post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(post.body),
                if (post.location != null && post.location!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: Text(post.location!)),
                    ],
                  ),
                ],
                if (post.scheduleText != null &&
                    post.scheduleText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.schedule_outlined,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: Text(post.scheduleText!)),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Liberação: ${formatMuralDateTime(post.releasedAt)}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  'Efetividade: ${formatMuralDateTime(post.effectiveAt)}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (onEdit != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editar'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
