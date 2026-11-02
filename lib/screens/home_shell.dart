import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../forms/form_question_repository.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../shell/shell_tabs.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import '../users/user_role.dart';
import 'children_screen.dart';
import 'form_questions_screen.dart';
import 'module_placeholder_screen.dart';
import 'mural_screen.dart';
import 'presence_home_body.dart';
import 'role_shell_view.dart';
import 'user_menu_body.dart';
import 'user_profile_screen.dart';
import 'users_screen.dart';

/// Post-login shell: bottom tabs by role (default = profile focus) and a
/// Menu tab with account + sitemap. Presença keeps [PresenceHomeBody];
/// empty modules use placeholders until their features land.
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
          childRepository: childRepository,
        ),
      ),
    );
  }

  void _openChildren(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChildrenScreen(
          profile: profile,
          childRepository: childRepository,
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

  Widget _buildModule(
    BuildContext context,
    ShellModule module,
    void Function(ShellModule) selectModule,
  ) {
    switch (module) {
      case ShellModule.presenca:
        return PresenceHomeBody(
          profile: profile,
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          formQuestionRepository: formQuestionRepository,
          userRepository: userRepository,
        );
      case ShellModule.mural:
        final greetingName = profile.displayName?.trim();
        final greeting = profile.role == UserRole.responsavel
            ? (greetingName != null && greetingName.isNotEmpty
                ? 'Olá, $greetingName!'
                : 'Bem-vindo ao Conecta Creche')
            : null;
        return MuralScreen(
          mostrarAppBar: true,
          saudacao: greeting,
          podePublicar: profile.role.canInactivateChild,
          autorNome: greetingName != null && greetingName.isNotEmpty
              ? greetingName
              : 'Equipe da creche',
          autorCargo: profile.role.label,
        );
      case ShellModule.incidentes:
        return const ModulePlaceholderScreen(
          title: 'Incidentes',
          message:
              'Em breve a visão global de incidentes da gestão estará aqui.',
        );
      case ShellModule.relatorios:
        return const ModulePlaceholderScreen(
          title: 'Relatórios',
          message:
              'Em breve você poderá acompanhar a rotina das crianças vinculadas.',
        );
      case ShellModule.menu:
        final tabs = shellTabsFor(profile.role);
        return Scaffold(
          appBar: AppBar(title: const Text('Menu')),
          body: UserMenuBody(
            profile: profile,
            moduleTabs:
                tabs.where((t) => t.module != ShellModule.menu).toList(),
            onSelectModule: selectModule,
            onOpenUsers:
                profile.canManageUsers ? () => _openUsers(context) : null,
            onOpenChildren: profile.role.canOperatePresence
                ? () => _openChildren(context)
                : null,
            onOpenForms: profile.role.canConfigureForms
                ? () => _openForms(context)
                : null,
            onOpenProfile: () => _openProfile(context),
            onSignOut: authService.signOut,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = shellTabsFor(profile.role);
    if (tabs.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Sem acesso operacional.')),
      );
    }

    return RoleShellView(
      tabs: tabs,
      initialIndex: defaultShellTabIndex(profile.role),
      buildBody: _buildModule,
    );
  }
}
