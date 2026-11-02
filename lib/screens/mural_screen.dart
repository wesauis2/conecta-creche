import 'package:flutter/material.dart';

import '../mural/mural_feed.dart';
import '../mural/mural_post.dart';
import '../mural/mural_repository.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../mural/notification_repository.dart';
import '../users/user_role.dart';
import 'mural_post_form_screen.dart';

/// Timeline do mural ordenada por efetividade. Mistura posts liberados,
/// notificações registradas e (para responsável) presenças/incidentes das
/// crianças vinculadas. Gestão+ publica/edita posts oficiais.
class MuralScreen extends StatefulWidget {
  const MuralScreen({
    super.key,
    required this.repository,
    required this.authorUid,
    this.role = UserRole.convidado,
    this.notificationRepository,
    this.childRepository,
    this.presenceRepository,
    this.podePublicar = false,
    this.mostrarAppBar = true,
    this.saudacao,
  });

  final MuralPostsRepository repository;
  final String authorUid;
  final UserRole role;
  final NotificationsRepository? notificationRepository;
  final ChildRepository? childRepository;
  final PresenceRepository? presenceRepository;
  final bool podePublicar;
  final bool mostrarAppBar;
  final String? saudacao;

  @override
  State<MuralScreen> createState() => _MuralScreenState();
}

class _MuralScreenState extends State<MuralScreen> {
  static const int _pageSize = 20;

  final List<MuralFeedItem> _items = <MuralFeedItem>[];
  final Set<String> _expandedIds = <String>{};
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  MuralFeedItemKind? _filtroTipo;
  MuralPostKind? _filtroPostKind;

  MuralFeedLoader? get _feedLoader {
    final notifications = widget.notificationRepository;
    final children = widget.childRepository;
    final presence = widget.presenceRepository;
    if (notifications == null || children == null || presence == null) {
      return null;
    }
    return MuralFeedLoader(
      muralRepository: widget.repository,
      notificationRepository: notifications,
      childRepository: children,
      presenceRepository: presence,
    );
  }

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

  Future<List<MuralFeedItem>> _loadPage({
    int pageSize = _pageSize,
    DateTime? startAfterEffectiveAt,
    String? startAfterId,
  }) async {
    final loader = _feedLoader;
    if (loader != null) {
      return loader.load(
        uid: widget.authorUid,
        role: widget.role,
        pageSize: pageSize,
        startAfterEffectiveAt: startAfterEffectiveAt,
        startAfterId: startAfterId,
      );
    }

    // Fallback legado (previews/dev sem repos extras): só posts.
    if (widget.podePublicar) {
      final all =
          await widget.repository.watchPosts(includeUnreleased: true).first;
      Iterable<MuralPost> page = all;
      if (startAfterEffectiveAt != null && startAfterId != null) {
        page = all.where((post) {
          final cmp = post.effectiveAt.compareTo(startAfterEffectiveAt);
          if (cmp != 0) return cmp < 0;
          return 'post:${post.id}'.compareTo(startAfterId) < 0;
        });
      }
      return page
          .take(pageSize)
          .map(
            (post) => MuralFeedItem(
              id: 'post:${post.id}',
              kind: MuralFeedItemKind.post,
              effectiveAt: post.effectiveAt,
              title: post.title,
              body: post.body,
              post: post,
              showUnreleasedBadge: !post.isReleased(),
            ),
          )
          .toList(growable: false);
    }

    final posts = await widget.repository.listVisiblePosts(
      pageSize: pageSize,
      startAfterEffectiveAt: startAfterEffectiveAt,
      startAfterId: startAfterId?.startsWith('post:') == true
          ? startAfterId!.substring('post:'.length)
          : startAfterId,
    );
    return posts
        .map(
          (post) => MuralFeedItem(
            id: 'post:${post.id}',
            kind: MuralFeedItemKind.post,
            effectiveAt: post.effectiveAt,
            title: post.title,
            body: post.body,
            post: post,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final page = await _loadPage(pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
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

  Future<void> _loadMore() async {
    if (_items.isEmpty || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final last = _items.last;
    try {
      final next = await _loadPage(
        pageSize: _pageSize,
        startAfterEffectiveAt: last.effectiveAt,
        startAfterId: last.id,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(next);
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

  List<MuralFeedItem> get _visiveis {
    return _items.where((item) {
      if (_filtroTipo != null && item.kind != _filtroTipo) return false;
      if (_filtroPostKind != null) {
        if (item.kind != MuralFeedItemKind.post) return false;
        if (item.post?.kind != _filtroPostKind) return false;
      }
      return true;
    }).toList();
  }

  Widget _tipoChip(String label, MuralFeedItemKind? kind) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filtroTipo == kind && _filtroPostKind == null,
        onSelected: (_) => setState(() {
          _filtroTipo = kind;
          _filtroPostKind = null;
        }),
      ),
    );
  }

  Widget _postKindChip(MuralPostKind kind) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(kind.label),
        selected: _filtroPostKind == kind,
        onSelected: (_) => setState(() {
          _filtroTipo = MuralFeedItemKind.post;
          _filtroPostKind = kind;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visiveis = _visiveis;
    final showChildFilters = widget.role == UserRole.responsavel;

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
                                  _tipoChip('Tudo', null),
                                  _tipoChip('Posts', MuralFeedItemKind.post),
                                  _tipoChip(
                                    'Avisos',
                                    MuralFeedItemKind.notification,
                                  ),
                                  if (showChildFilters) ...[
                                    _tipoChip(
                                      'Presença',
                                      MuralFeedItemKind.presence,
                                    ),
                                    _tipoChip(
                                      'Incidentes',
                                      MuralFeedItemKind.incident,
                                    ),
                                  ],
                                  for (final kind in MuralPostKind.values)
                                    _postKindChip(kind),
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

                      final item = visiveis[postIndex];
                      final expanded = _expandedIds.contains(item.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MuralFeedTile(
                          key: ValueKey(item.id),
                          item: item,
                          expanded: expanded,
                          onToggle: () => setState(() {
                            if (expanded) {
                              _expandedIds.remove(item.id);
                            } else {
                              _expandedIds.add(item.id);
                            }
                          }),
                          onEdit: widget.podePublicar &&
                                  item.kind == MuralFeedItemKind.post &&
                                  item.post != null
                              ? () => _novaPublicacao(existing: item.post)
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

class _MuralFeedTile extends StatelessWidget {
  const _MuralFeedTile({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
    this.onEdit,
  });

  final MuralFeedItem item;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  IconData get _icon => switch (item.kind) {
        MuralFeedItemKind.post =>
          item.post?.kind.icon ?? Icons.campaign_outlined,
        MuralFeedItemKind.notification => Icons.notifications_outlined,
        MuralFeedItemKind.presence => Icons.child_care_outlined,
        MuralFeedItemKind.incident => Icons.report_problem_outlined,
      };

  String get _kindLabel => switch (item.kind) {
        MuralFeedItemKind.post => item.post?.kind.label ?? 'Publicação',
        MuralFeedItemKind.notification => 'Aviso',
        MuralFeedItemKind.presence => 'Presença',
        MuralFeedItemKind.incident => 'Incidente',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final post = item.post;

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
                  Icon(_icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    _kindLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMuralDate(item.effectiveAt),
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (item.showUnreleasedBadge && post != null) ...[
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
                item.title,
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (!expanded) ...[
                const SizedBox(height: 4),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(item.body),
                if (post != null) ...[
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
                ],
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
