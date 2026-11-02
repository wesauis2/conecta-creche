import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../forms/form_question_repository.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import '../users/user_role.dart';
import 'form_questions_screen.dart';
import 'mural_screen.dart';
import 'presence_home_body.dart';
import 'user_profile_screen.dart';
import 'users_screen.dart';

/// Thin post-login shell: owns the auth-dependent app bar shortcuts (perfil/
/// usuários / formulários) and hands role-based routing off to
/// [PresenceHomeBody], which only needs [profile] and the presence repos.
/// Kept thin on purpose so the routing logic stays testable without
/// `GoogleAuthService`/`UserRepository`. See ticket 07.
///
/// Temporary exception: [UserRole.responsavel] lands on [MuralScreen] as home
/// (from the mural/responsáveis tip). Equipe roles stay on presence; refactor
/// later to unify entry points. Formulários stays reachable here until the
/// Menu tab (shell) lands.
class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.profile,
    required this.authService,
    required this.userRepository,
    required this.childRepository,
    required this.presenceRepository,
    required this.formQuestionRepository,
  });

  final UserProfile profile;
  final GoogleAuthService authService;
  final UserRepository userRepository;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;
  final FormQuestionRepository formQuestionRepository;

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

  void _openUsers(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UsersScreen(
          profile: profile,
          userRepository: userRepository,
        ),
      ),
    );
  }

  void _openForms(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FormQuestionsScreen(
          profile: profile,
          formQuestionRepository: formQuestionRepository,
        ),
      ),
    );
  }

  List<Widget> _appBarActions(BuildContext context) {
    return [
      if (profile.role.canConfigureForms)
        IconButton(
          onPressed: () => _openForms(context),
          tooltip: 'Formulários',
          icon: const Icon(Icons.fact_check_outlined),
        ),
      if (profile.canManageUsers)
        IconButton(
          onPressed: () => _openUsers(context),
          tooltip: 'Usuários',
          icon: const Icon(Icons.group_outlined),
        ),
      IconButton(
        onPressed: () => _openProfile(context),
        tooltip: 'Meu perfil',
        icon: const Icon(Icons.person_outline),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final actions = _appBarActions(context);

    // Responsáveis open the app on the mural; do not alter equipe presence homes.
    if (profile.role == UserRole.responsavel) {
      final greetingName = profile.displayName?.trim();
      final greeting = greetingName != null && greetingName.isNotEmpty
          ? 'Olá, $greetingName!'
          : 'Bem-vindo ao Conecta Creche';
      return Scaffold(
        appBar: AppBar(
          title: const Text('Conecta Creche'),
          actions: actions,
        ),
        body: MuralScreen(
          mostrarAppBar: false,
          saudacao: greeting,
        ),
      );
    }

    return PresenceHomeBody(
      profile: profile,
      childRepository: childRepository,
      presenceRepository: presenceRepository,
      appBarActions: actions,
    );
  }
}
