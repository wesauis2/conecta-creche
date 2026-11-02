import 'package:flutter/material.dart';

import '../forms/form_question_repository.dart';
import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import 'presence_day_screen.dart';
import 'presence_gestao_screen.dart';

/// Routes to the right presença home surface for `profile.role`: gestão/
/// admin land on the aggregate view, cuidador lands on the day view, and
/// other roles (responsável/convidado) get a placeholder — they never reach
/// the presence tab. See CONTEXT.md "Visão do cuidador" / "Visão da gestão".
///
/// Depends on [profile] and the presence repos (no `GoogleAuthService`), so
/// it can be widget-tested without Firebase Auth. Optional [userRepository]
/// enables vínculos child↔responsável na tela Crianças (gestão+).
/// [formQuestionRepository] enables ocorrências via answers no dia do cuidador.
/// [appBarActions] lets the shell inject extra app-bar actions when needed
/// (perfil/usuários live in Menu).
class PresenceHomeBody extends StatelessWidget {
  const PresenceHomeBody({
    super.key,
    required this.profile,
    required this.childRepository,
    required this.presenceRepository,
    this.formQuestionRepository,
    this.userRepository,
    this.appBarActions = const [],
  });

  final UserProfile profile;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;
  final FormQuestionRepository? formQuestionRepository;
  final UserRepository? userRepository;
  final List<Widget> appBarActions;

  @override
  Widget build(BuildContext context) {
    if (profile.role.canInactivateChild) {
      return PresenceGestaoScreen(
        profile: profile,
        childRepository: childRepository,
        presenceRepository: presenceRepository,
        userRepository: userRepository,
        appBarLeadingActions: appBarActions,
      );
    }
    if (profile.role.canOperatePresence) {
      return PresenceDayScreen(
        profile: profile,
        childRepository: childRepository,
        presenceRepository: presenceRepository,
        formQuestionRepository: formQuestionRepository,
        userRepository: userRepository,
        appBarLeadingActions: appBarActions,
      );
    }

    // Responsável/convidado: no presence entry point at all (see SPEC.md
    // "Out of Scope" / CONTEXT.md "Cuidador+").
    final greetingName = profile.displayName?.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conecta Creche'),
        actions: appBarActions,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greetingName != null && greetingName.isNotEmpty
                  ? 'Olá, $greetingName!'
                  : 'Bem-vindo ao Conecta Creche',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'Em breve você poderá acompanhar a rotina da creche por aqui.',
            ),
          ],
        ),
      ),
    );
  }
}
