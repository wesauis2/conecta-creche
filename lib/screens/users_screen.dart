import 'package:flutter/material.dart';

import '../users/user_profile.dart';
import '../users/user_repository.dart';
import '../users/user_role.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.profile,
    required this.userRepository,
  });

  final UserProfile profile;
  final UserRepository userRepository;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const _filterRoles = <UserRole>[
    UserRole.convidado,
    UserRole.responsavel,
    UserRole.cuidador,
    UserRole.gestao,
    UserRole.admin,
  ];

  UserRole _selectedFilter = UserRole.convidado;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserProfile> _filterUsers(List<UserProfile> users) {
    final query = _searchQuery.trim().toLowerCase();
    return users.where((user) {
      if (user.role != _selectedFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final name = (user.displayName ?? '').toLowerCase();
      final email = (user.email ?? '').toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  Future<void> _changeRole(UserProfile target) async {
    final caller = widget.profile;
    if (target.uid == caller.uid) {
      return;
    }
    if (!caller.role.canManage(target.role)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível gerenciar um papel acima do seu.'),
        ),
      );
      return;
    }

    final assignable = UserRole.values
        .where(caller.role.canAssign)
        .toList(growable: false);

    final selected = await showModalBottomSheet<UserRole>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(
                  'Alterar acesso',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  target.displayName?.trim().isNotEmpty == true
                      ? target.displayName!
                      : (target.email ?? target.uid),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final role in assignable)
                ListTile(
                  title: Text(role.label),
                  trailing: role == target.role
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(role),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == target.role || !mounted) {
      return;
    }

    try {
      await widget.userRepository.updateUserRole(
        targetUid: target.uid,
        newRole: selected,
        callerRole: caller.role,
        targetCurrentRole: target.role,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acesso atualizado para ${selected.label}.'),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível alterar o acesso: $error')),
        );
      }
    }
  }

  String _emptyMessage() {
    if (_selectedFilter == UserRole.convidado) {
      return 'Nenhum convidado aguardando.';
    }
    return 'Nenhum usuário neste filtro.';
  }

  String _initials(UserProfile user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.canManageUsers) {
      return Scaffold(
        appBar: AppBar(title: const Text('Usuários')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Você não tem permissão para ver esta área.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Pesquisar',
                hintText: 'Nome ou e-mail',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                for (final role in _filterRoles) ...[
                  FilterChip(
                    label: Text(role.filterLabel),
                    selected: _selectedFilter == role,
                    onSelected: (_) {
                      setState(() => _selectedFilter = role);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<UserProfile>>(
              stream: widget.userRepository.watchManagedUsers(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Não foi possível carregar os usuários.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _filterUsers(snapshot.data!);
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyMessage(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = filtered[index];
                    final isSelf = user.uid == widget.profile.uid;
                    final canEdit = !isSelf &&
                        widget.profile.role.canManage(user.role);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(_initials(user))
                            : null,
                      ),
                      title: Text(
                        user.displayName?.trim().isNotEmpty == true
                            ? user.displayName!
                            : (user.email ?? user.uid),
                      ),
                      subtitle: Text(user.email ?? user.uid),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(user.role.filterLabel),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (canEdit) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Alterar acesso',
                              onPressed: () => _changeRole(user),
                              icon: const Icon(Icons.manage_accounts_outlined),
                            ),
                          ],
                        ],
                      ),
                      onTap: canEdit ? () => _changeRole(user) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
