import 'package:conecta_creche/screens/role_shell_view.dart';
import 'package:conecta_creche/shell/shell_tabs.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke: role tab chrome selects the profile-focus tab and Menu shortcuts
/// switch modules without stacking a new route.
void main() {
  Future<RoleShellViewState> pumpShell(
    WidgetTester tester, {
    required UserRole role,
  }) async {
    final tabs = shellTabsFor(role);
    await tester.pumpWidget(
      MaterialApp(
        home: RoleShellView(
          tabs: tabs,
          initialIndex: defaultShellTabIndex(role),
          buildBody: (context, module, selectModule) {
            return Scaffold(
              body: Column(
                children: [
                  Text('body-${module.name}', key: ValueKey('body-${module.name}')),
                  if (module == ShellModule.menu)
                    TextButton(
                      onPressed: () => selectModule(ShellModule.mural),
                      child: const Text('ir-mural'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<RoleShellViewState>(find.byType(RoleShellView));
  }

  testWidgets('cuidador default Presença e tabs corretas', (tester) async {
    final state = await pumpShell(tester, role: UserRole.cuidador);

    expect(state.currentModule, ShellModule.presenca);
    expect(find.text('Presença'), findsWidgets);
    expect(find.text('Mural'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Incidentes'), findsNothing);
    expect(find.byKey(const ValueKey('body-presenca')), findsOneWidget);
  });

  testWidgets('gestão default Incidentes', (tester) async {
    final state = await pumpShell(tester, role: UserRole.gestao);

    expect(state.currentModule, ShellModule.incidentes);
    expect(find.byKey(const ValueKey('body-incidentes')), findsOneWidget);
    expect(find.text('Incidentes'), findsWidgets);
    expect(find.text('Presença'), findsOneWidget);
  });

  testWidgets('responsável default Relatórios', (tester) async {
    final state = await pumpShell(tester, role: UserRole.responsavel);

    expect(state.currentModule, ShellModule.relatorios);
    expect(find.byKey(const ValueKey('body-relatorios')), findsOneWidget);
    expect(find.text('Relatórios'), findsWidgets);
  });

  testWidgets('atalho do Menu seleciona a tab Mural', (tester) async {
    final state = await pumpShell(tester, role: UserRole.cuidador);

    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(state.currentModule, ShellModule.menu);

    await tester.tap(find.text('ir-mural'));
    await tester.pumpAndSettle();
    expect(state.currentModule, ShellModule.mural);
    expect(find.byKey(const ValueKey('body-mural')), findsOneWidget);
  });
}
