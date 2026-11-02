import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../classes/class_repository.dart';
import '../forms/form_question_repository.dart';
import '../levels/level_repository.dart';
import '../mural/mural_reads_repository.dart';
import '../mural/mural_repository.dart';
import '../mural/notification_repository.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../shell/shell_tabs.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import '../users/user_role.dart';
import 'children_screen.dart';
import 'classes_screen.dart';
import 'form_questions_screen.dart';
import 'incidentes_screen.dart';
import 'levels_screen.dart';
import 'mural_screen.dart';
import 'presence_home_body.dart';
import 'relatorios_screen.dart';
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
    required this.levelRepository,
    required this.classRepository,
    required this.muralRepository,
    required this.notificationRepository,
    required this.muralReadsRepository,
  });

  final UserProfile profile;
  final GoogleAuthService authService;
  final UserRepository userRepository;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;
  final FormQuestionRepository formQuestionRepository;
  final LevelRepository levelRepository;
  final ClassRepository classRepository;
  final MuralPostsRepository muralRepository;
  final NotificationsRepository notificationRepository;
  final MuralReadsRepository muralReadsRepository;

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
          levelRepository: levelRepository,
          classRepository: classRepository,
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

  void _openLevels(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LevelsScreen(
          profile: profile,
          levelRepository: levelRepository,
        ),
      ),
    );
  }

  void _openClasses(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ClassesScreen(
          profile: profile,
          classRepository: classRepository,
          levelRepository: levelRepository,
          childRepository: childRepository,
          userRepository: userRepository,
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
          repository: muralRepository,
          authorUid: profile.uid,
          role: profile.role,
          notificationRepository: notificationRepository,
          muralReadsRepository: muralReadsRepository,
          childRepository: childRepository,
          presenceRepository: presenceRepository,
          mostrarAppBar: true,
          saudacao: greeting,
          podePublicar: profile.role.canPublishMural,
        );
      case ShellModule.incidentes:
        return IncidentesScreen(
          presenceRepository: presenceRepository,
          childRepository: childRepository,
        );
      case ShellModule.relatorios:
        return RelatoriosScreen(
          responsibleUid: profile.uid,
          childRepository: childRepository,
          presenceRepository: presenceRepository,
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
            onOpenLevels: profile.role.canManageLevelsAndClasses
                ? () => _openLevels(context)
                : null,
            onOpenClasses: profile.role.canManageLevelsAndClasses
                ? () => _openClasses(context)
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
