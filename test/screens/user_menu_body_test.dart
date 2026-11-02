import 'package:conecta_creche/screens/user_menu_body.dart';
import 'package:conecta_creche/shell/shell_tabs.dart';
import 'package:conecta_creche/users/user_profile.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile(UserRole role) => UserProfile(
      uid: 'uid-${role.name}',
      role: role,
      displayName: 'Maria Silva',
      email: 'maria@example.com',
    );

void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    required UserRole role,
    void Function(ShellModule)? onSelectModule,
    VoidCallback? onOpenUsers,
    VoidCallback? onOpenChildren,
    VoidCallback? onOpenForms,
    VoidCallback? onOpenProfile,
    VoidCallback? onSignOut,
  }) async {
    final profile = _profile(role);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserMenuBody(
            profile: profile,
            moduleTabs: shellTabsFor(role)
                .where((t) => t.module != ShellModule.menu)
                .toList(),
            onSelectModule: onSelectModule ?? (_) {},
            // Mirrors HomeShell: optional destinations appear only when wired.
            onOpenUsers: onOpenUsers ??
                (profile.canManageUsers ? () {} : null),
            onOpenChildren: onOpenChildren ??
                (role.canOperatePresence ? () {} : null),
            onOpenForms: onOpenForms ??
                (role.canInactivateChild ? () {} : null),
            onOpenProfile: onOpenProfile ?? () {},
            onSignOut: onSignOut ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('mostra identidade com nome e papel', (tester) async {
    await pumpMenu(tester, role: UserRole.cuidador);

    expect(find.text('Maria Silva'), findsOneWidget);
    expect(find.text('Cuidador'), findsOneWidget);
  });

  testWidgets('cuidador: atalhos de módulo + Crianças + Perfil + Sair',
      (tester) async {
    await pumpMenu(tester, role: UserRole.cuidador);

    expect(find.text('Presença'), findsOneWidget);
    expect(find.text('Mural'), findsOneWidget);
    expect(find.text('Crianças'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Usuários'), findsNothing);
    expect(find.text('Formulários'), findsNothing);
  });

  testWidgets('gestão: Usuários e Formulários quando canManageUsers',
      (tester) async {
    await pumpMenu(tester, role: UserRole.gestao);

    expect(find.text('Incidentes'), findsOneWidget);
    expect(find.text('Usuários'), findsOneWidget);
    expect(find.text('Formulários'), findsOneWidget);
    expect(find.text('Crianças'), findsOneWidget);
  });

  testWidgets('responsável: módulos + Perfil + Sair, sem catálogo staff',
      (tester) async {
    await pumpMenu(tester, role: UserRole.responsavel);

    expect(find.text('Relatórios'), findsOneWidget);
    expect(find.text('Mural'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Crianças'), findsNothing);
    expect(find.text('Usuários'), findsNothing);
    expect(find.text('Formulários'), findsNothing);
  });

  testWidgets('atalho de módulo chama onSelectModule', (tester) async {
    ShellModule? selected;
    await pumpMenu(
      tester,
      role: UserRole.cuidador,
      onSelectModule: (module) => selected = module,
    );

    await tester.tap(find.text('Mural'));
    expect(selected, ShellModule.mural);
  });
}
