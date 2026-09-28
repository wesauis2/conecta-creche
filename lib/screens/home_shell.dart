import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import '../users/user_role.dart';
import 'mural_screen.dart';
import 'responsaveis_list_screen.dart';
import 'user_profile_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.profile,
    required this.authService,
    required this.userRepository,
  });

  final UserProfile profile;
  final GoogleAuthService authService;
  final UserRepository userRepository;

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen(
          profile: profile,
          authService: authService,
          userRepository: userRepository,
        ),
      ),
    );
  }

  void _openResponsaveis(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ResponsaveisListScreen(),
      ),
    );
  }

  void _openMural(BuildContext context) {
    final nome = profile.displayName?.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MuralScreen(
          podePublicar: true,
          autorNome: (nome != null && nome.isNotEmpty) ? nome : 'Equipe',
          autorCargo: _cargoLabel,
        ),
      ),
    );
  }

  bool get _isEquipe =>
      profile.role == UserRole.admin ||
      profile.role == UserRole.gestao ||
      profile.role == UserRole.cuidador;

  bool get _isResponsavel => profile.role == UserRole.responsavel;

  String get _cargoLabel => switch (profile.role) {
        UserRole.admin => 'Administração',
        UserRole.gestao => 'Gestão',
        UserRole.cuidador => 'Cuidador(a)',
        _ => 'Equipe',
      };

  @override
  Widget build(BuildContext context) {
    final greetingName = profile.displayName?.trim();
    final greeting = greetingName != null && greetingName.isNotEmpty
        ? 'Olá, $greetingName!'
        : 'Bem-vindo ao Conecta Creche';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conecta Creche'),
        actions: [
          IconButton(
            onPressed: () => _openProfile(context),
            tooltip: 'Meu perfil',
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: _isResponsavel
          // Responsáveis já abrem o app direto no mural.
          ? MuralScreen(mostrarAppBar: false, saudacao: greeting)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (_isEquipe) ...[
                    Text(
                      'Gestão',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _FeatureCard(
                      icon: Icons.dashboard_outlined,
                      title: 'Mural',
                      subtitle:
                          'Publique fotos, avisos e lembretes para as famílias.',
                      onTap: () => _openMural(context),
                    ),
                    const SizedBox(height: 8),
                    _FeatureCard(
                      icon: Icons.people_outline,
                      title: 'Responsáveis',
                      subtitle:
                          'Consulte e cadastre os responsáveis pelas crianças.',
                      onTap: () => _openResponsaveis(context),
                    ),
                    const SizedBox(height: 8),
                    const _FeatureCard(
                      icon: Icons.child_care_outlined,
                      title: 'Crianças',
                      subtitle: 'Em breve.',
                      enabled: false,
                    ),
                  ] else
                    const Text(
                      'Em breve você poderá acompanhar a rotina da creche por aqui.',
                    ),
                ],
              ),
            ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: enabled ? const Icon(Icons.chevron_right) : null,
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}
