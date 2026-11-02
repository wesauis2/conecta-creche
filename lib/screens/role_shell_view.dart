import 'package:flutter/material.dart';

import '../shell/shell_tabs.dart';

/// Bottom-tab chrome: [NavigationBar] + module body. Auth-free so widget
/// tests can cover role routing without Firebase.
class RoleShellView extends StatefulWidget {
  const RoleShellView({
    super.key,
    required this.tabs,
    required this.initialIndex,
    required this.buildBody,
  });

  final List<ShellTabSpec> tabs;
  final int initialIndex;

  /// Builds the body for [module]. [selectModule] switches the bottom tab
  /// when the destination is already a tab (e.g. Menu shortcuts).
  final Widget Function(
    BuildContext context,
    ShellModule module,
    void Function(ShellModule module) selectModule,
  ) buildBody;

  @override
  State<RoleShellView> createState() => RoleShellViewState();
}

@visibleForTesting
class RoleShellViewState extends State<RoleShellView> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);
  }

  int get currentIndex => _index;

  ShellModule get currentModule => widget.tabs[_index].module;

  void selectModule(ShellModule module) {
    final next = indexOfShellModule(widget.tabs, module);
    if (next == null || next == _index) return;
    setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.tabs[_index].module;
    return Scaffold(
      body: widget.buildBody(context, module, selectModule),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          for (final tab in widget.tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
