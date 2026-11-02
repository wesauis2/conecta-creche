import 'package:flutter/material.dart';

import '../users/user_role.dart';

/// First-level modules exposed as bottom tabs (and as Menu shortcuts).
enum ShellModule {
  incidentes,
  presenca,
  mural,
  relatorios,
  menu,
}

/// One entry in the role's bottom [NavigationBar].
class ShellTabSpec {
  const ShellTabSpec({
    required this.module,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final ShellModule module;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _presenca = ShellTabSpec(
  module: ShellModule.presenca,
  label: 'Presença',
  icon: Icons.fact_check_outlined,
  selectedIcon: Icons.fact_check,
);

const _mural = ShellTabSpec(
  module: ShellModule.mural,
  label: 'Mural',
  icon: Icons.newspaper_outlined,
  selectedIcon: Icons.newspaper,
);

const _menu = ShellTabSpec(
  module: ShellModule.menu,
  label: 'Menu',
  icon: Icons.menu_outlined,
  selectedIcon: Icons.menu,
);

const _incidentes = ShellTabSpec(
  module: ShellModule.incidentes,
  label: 'Incidentes',
  icon: Icons.report_outlined,
  selectedIcon: Icons.report,
);

const _relatorios = ShellTabSpec(
  module: ShellModule.relatorios,
  label: 'Relatórios',
  icon: Icons.insights_outlined,
  selectedIcon: Icons.insights,
);

/// Bottom tabs for [role]. Empty for `convidado` (stays on the approval gate).
List<ShellTabSpec> shellTabsFor(UserRole role) {
  return switch (role) {
    UserRole.cuidador => const [_presenca, _mural, _menu],
    UserRole.gestao || UserRole.admin => const [
        _incidentes,
        _presenca,
        _mural,
        _menu,
      ],
    UserRole.responsavel => const [_relatorios, _mural, _menu],
    UserRole.convidado => const [],
  };
}

/// Index of the profile-focus tab when the shell opens.
int defaultShellTabIndex(UserRole role) {
  final tabs = shellTabsFor(role);
  if (tabs.isEmpty) return 0;

  final focus = switch (role) {
    UserRole.cuidador => ShellModule.presenca,
    UserRole.gestao || UserRole.admin => ShellModule.incidentes,
    UserRole.responsavel => ShellModule.relatorios,
    UserRole.convidado => ShellModule.menu,
  };

  return indexOfShellModule(tabs, focus) ?? 0;
}

int? indexOfShellModule(List<ShellTabSpec> tabs, ShellModule module) {
  final index = tabs.indexWhere((tab) => tab.module == module);
  return index >= 0 ? index : null;
}
