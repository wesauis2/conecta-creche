import 'package:flutter/material.dart';

import '../presence/child_repository.dart';
import '../presence/presence_repository.dart';
import '../users/user_profile.dart';
import 'presence_day_screen.dart';
import 'presence_gestao_screen.dart';

/// Routes to the right presença home surface for `profile.role`: gestão/
/// admin land on the aggregate view, cuidador lands on the day view, and
/// other roles (responsável/convidado) get a placeholder — they never reach
/// the presence surfaces. See CONTEXT.md "Visão do cuidador" / "Visão da
/// gestão" and SPEC.md "Home: cuidador → detalhe do dia; gestão/admin →
/// agregado."
///
/// Depends only on [profile] and the presence repos (no
/// `GoogleAuthService`/`UserRepository`), so it can be widget-tested
/// directly without touching Firebase Auth. [appBarActions] lets the caller
/// (`HomeShell`) inject auth-dependent shortcuts (perfil/usuários) into
/// whichever screen ends up owning the app's only app bar.
class PresenceHomeBody extends StatelessWidget {
  const PresenceHomeBody({
    super.key,
    required this.profile,
    required this.childRepository,
    required this.presenceRepository,
    this.appBarActions = const [],
  });

  final UserProfile profile;
  final ChildRepository childRepository;
  final PresenceRepository presenceRepository;
  final List<Widget> appBarActions;

  @override
  Widget build(BuildContext context) {
    if (profile.role.canInactivateChild) {
      return PresenceGestaoScreen(
        profile: profile,
        childRepository: childRepository,
        presenceRepository: presenceRepository,
        appBarLeadingActions: appBarActions,
      );
    }
    if (profile.role.canOperatePresence) {
      return PresenceDayScreen(
        profile: profile,
        childRepository: childRepository,
        presenceRepository: presenceRepository,
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
