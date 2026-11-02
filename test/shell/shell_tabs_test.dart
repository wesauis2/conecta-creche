import 'package:conecta_creche/shell/shell_tabs.dart';
import 'package:conecta_creche/users/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shellTabsFor', () {
    test('cuidador: Presença · Mural · Menu', () {
      expect(
        shellTabsFor(UserRole.cuidador).map((t) => t.module).toList(),
        [ShellModule.presenca, ShellModule.mural, ShellModule.menu],
      );
      expect(
        shellTabsFor(UserRole.cuidador).map((t) => t.label).toList(),
        ['Presença', 'Mural', 'Menu'],
      );
    });

    test('gestão: Incidentes · Presença · Mural · Menu', () {
      expect(
        shellTabsFor(UserRole.gestao).map((t) => t.module).toList(),
        [
          ShellModule.incidentes,
          ShellModule.presenca,
          ShellModule.mural,
          ShellModule.menu,
        ],
      );
    });

    test('admin herda tabs de gestão', () {
      expect(
        shellTabsFor(UserRole.admin).map((t) => t.module).toList(),
        shellTabsFor(UserRole.gestao).map((t) => t.module).toList(),
      );
    });

    test('responsável: Relatórios · Mural · Menu', () {
      expect(
        shellTabsFor(UserRole.responsavel).map((t) => t.module).toList(),
        [ShellModule.relatorios, ShellModule.mural, ShellModule.menu],
      );
    });

    test('convidado não tem shell operacional', () {
      expect(shellTabsFor(UserRole.convidado), isEmpty);
    });
  });

  group('defaultShellTabIndex', () {
    test('cuidador abre em Presença', () {
      final tabs = shellTabsFor(UserRole.cuidador);
      final index = defaultShellTabIndex(UserRole.cuidador);
      expect(tabs[index].module, ShellModule.presenca);
    });

    test('gestão e admin abrem em Incidentes', () {
      for (final role in [UserRole.gestao, UserRole.admin]) {
        final tabs = shellTabsFor(role);
        final index = defaultShellTabIndex(role);
        expect(tabs[index].module, ShellModule.incidentes);
      }
    });

    test('responsável abre em Relatórios', () {
      final tabs = shellTabsFor(UserRole.responsavel);
      final index = defaultShellTabIndex(UserRole.responsavel);
      expect(tabs[index].module, ShellModule.relatorios);
    });
  });

  group('indexOfShellModule', () {
    test('encontra módulo presente e retorna null se ausente', () {
      final tabs = shellTabsFor(UserRole.cuidador);
      expect(indexOfShellModule(tabs, ShellModule.mural), 1);
      expect(indexOfShellModule(tabs, ShellModule.incidentes), isNull);
    });
  });
}
