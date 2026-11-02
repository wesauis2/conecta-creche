import 'package:flutter/material.dart';

import '../shell/shell_tabs.dart';
import '../users/user_profile.dart';

/// Menu do usuário: identidade + sitemap (tabs + telas auxiliares + sair).
class UserMenuBody extends StatelessWidget {
  const UserMenuBody({
    super.key,
    required this.profile,
    required this.moduleTabs,
    required this.onSelectModule,
    required this.onOpenProfile,
    required this.onSignOut,
    this.onOpenUsers,
    this.onOpenChildren,
    this.onOpenForms,
  });

  final UserProfile profile;

  /// Module tabs excluding [ShellModule.menu] — shown as shortcuts that
  /// select the corresponding bottom tab.
  final List<ShellTabSpec> moduleTabs;

  final void Function(ShellModule module) onSelectModule;
  final VoidCallback onOpenProfile;
  final VoidCallback onSignOut;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenChildren;
  final VoidCallback? onOpenForms;

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName?.trim();
    final title = name != null && name.isNotEmpty ? name : 'Conta';
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          profile.role.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        if (profile.email != null && profile.email!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            profile.email!.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Módulos',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        for (final tab in moduleTabs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(tab.icon),
            title: Text(tab.label),
            onTap: () => onSelectModule(tab.module),
          ),
        const SizedBox(height: 12),
        Text(
          'Conta e administração',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        if (onOpenUsers != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_outlined),
            title: const Text('Usuários'),
            onTap: onOpenUsers,
          ),
        if (onOpenChildren != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.child_care_outlined),
            title: const Text('Crianças'),
            onTap: onOpenChildren,
          ),
        if (onOpenForms != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dynamic_form_outlined),
            title: const Text('Formulários'),
            onTap: onOpenForms,
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: const Text('Perfil'),
          onTap: onOpenProfile,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout),
          title: const Text('Sair'),
          onTap: onSignOut,
        ),
      ],
    );
  }
}
