import 'package:flutter/material.dart';

import '../classes/class_repository.dart';
import '../classes/school_class.dart';
import '../levels/level.dart';
import '../levels/level_repository.dart';
import '../presence/child.dart';
import '../presence/child_repository.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';
import '../users/user_role.dart';

/// Catálogo de crianças, separado da lista operacional de presença. See
/// CONTEXT.md "Gestão de crianças" / "Inativação de criança" /
/// "Vínculo criança↔responsável".
class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({
    super.key,
    required this.profile,
    required this.childRepository,
    this.userRepository,
    this.levelRepository,
    this.classRepository,
  });

  final UserProfile profile;
  final ChildRepository childRepository;

  /// Necessário para gestão+ vincular responsáveis; ausente em testes
  /// focados só no catálogo.
  final UserRepository? userRepository;

  /// Gestão+ seleciona nível/turma na ficha; opcional em testes de catálogo.
  final LevelRepository? levelRepository;
  final ClassRepository? classRepository;

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  Future<void> _editName(Child child) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => _EditNameDialog(initialName: child.name),
    );

    if (newName == null || newName.isEmpty || !mounted) {
      return;
    }
    if (newName == child.name) {
      return;
    }

    try {
      await widget.childRepository.updateChild(
        childId: child.id,
        name: newName,
        updatedBy: widget.profile.uid,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar o nome: $error')),
        );
      }
    }
  }

  Future<void> _editLevelAndClass(Child child) async {
    final levelRepository = widget.levelRepository;
    final classRepository = widget.classRepository;
    if (levelRepository == null || classRepository == null) {
      return;
    }

    final result = await showDialog<_PlacementDraft>(
      context: context,
      builder: (context) => _SelectPlacementDialog(
        levelRepository: levelRepository,
        classRepository: classRepository,
        childName: child.name,
        initialLevelId: child.levelId,
        initialClassId: child.classId,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final sameLevel = result.levelId == child.levelId;
    final sameClass = result.classId == child.classId;
    if (sameLevel && sameClass) {
      return;
    }

    try {
      await widget.childRepository.updateChild(
        childId: child.id,
        updatedBy: widget.profile.uid,
        levelId: result.levelId,
        clearLevelId: result.levelId == null,
        classId: result.classId,
        clearClassId: result.classId == null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nível/turma de ${child.name} atualizados.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar nível/turma: $error'),
          ),
        );
      }
    }
  }

  Future<void> _editResponsibles(Child child) async {
    final userRepository = widget.userRepository;
    if (userRepository == null) {
      return;
    }

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _SelectResponsiblesDialog(
        userRepository: userRepository,
        initiallySelected: child.responsibleUids.toSet(),
        childName: child.name,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    final current = child.responsibleUids.toSet();
    if (selected.length == current.length && selected.containsAll(current)) {
      return;
    }

    try {
      await widget.childRepository.setChildResponsibles(
        childId: child.id,
        responsibleUids: selected.toList(growable: false),
        updatedBy: widget.profile.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Responsáveis de ${child.name} atualizados.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar os responsáveis: $error'),
          ),
        );
      }
    }
  }

  Future<void> _confirmInactivate(Child child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Inativar criança'),
          content: Text(
            '${child.name} vai sumir da lista operacional de presença. '
            'O histórico é mantido e você pode reativar depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Inativar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _setActive(child, false);
  }

  Future<void> _setActive(Child child, bool active) async {
    try {
      await widget.childRepository.updateChild(
        childId: child.id,
        active: active,
        updatedBy: widget.profile.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? '${child.name} reativada.'
                  : '${child.name} inativada.',
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.role.canOperatePresence) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crianças')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Você não tem permissão para ver esta área.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final canInactivate = widget.profile.role.canInactivateChild;
    final canManageLinks =
        canInactivate && widget.userRepository != null;
    final canManagePlacement = widget.profile.role.canManageLevelsAndClasses &&
        widget.levelRepository != null &&
        widget.classRepository != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Crianças')),
      body: StreamBuilder<List<Child>>(
        stream: widget.childRepository.watchChildren(
          activeOnly: !canInactivate,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as crianças.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = snapshot.data!;
          if (children.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  canInactivate
                      ? 'Nenhuma criança cadastrada.'
                      : 'Nenhuma criança ativa cadastrada.\n'
                          'Cadastre uma pela tela de Presença.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<Level>>(
            stream: widget.levelRepository?.watchLevels() ??
                Stream.value(const <Level>[]),
            builder: (context, levelsSnap) {
              final levelsById = <String, Level>{
                for (final level in levelsSnap.data ?? const <Level>[])
                  level.id: level,
              };
              return StreamBuilder<List<SchoolClass>>(
                stream: widget.classRepository?.watchClasses() ??
                    Stream.value(const <SchoolClass>[]),
                builder: (context, classesSnap) {
                  final classesById = <String, SchoolClass>{
                    for (final c in classesSnap.data ?? const <SchoolClass>[])
                      c.id: c,
                  };

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemCount: children.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final child = children[index];
                      final levelName = child.levelId == null
                          ? null
                          : levelsById[child.levelId!]?.name;
                      final classLabel = child.classId == null
                          ? null
                          : classesById[child.classId!]?.displayLabel;
                      final subtitleParts = <String>[
                        if (!child.active) 'Inativa',
                        if (levelName != null) levelName,
                        if (classLabel != null) classLabel,
                        if (canManageLinks)
                          child.responsibleUids.isEmpty
                              ? 'Sem responsáveis'
                              : '${child.responsibleUids.length} '
                                  'responsável'
                                  '${child.responsibleUids.length == 1 ? '' : 'eis'}',
                      ];
                      return ListTile(
                        title: Text(child.name),
                        subtitle: subtitleParts.isEmpty
                            ? null
                            : Text(subtitleParts.join(' · ')),
                        leading: CircleAvatar(
                          child: Text(
                            child.name.isNotEmpty
                                ? child.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canManagePlacement)
                              IconButton(
                                tooltip: 'Nível e turma',
                                onPressed: () => _editLevelAndClass(child),
                                icon: const Icon(Icons.school_outlined),
                              ),
                            if (canManageLinks)
                              IconButton(
                                tooltip: 'Responsáveis',
                                onPressed: () => _editResponsibles(child),
                                icon: const Icon(Icons.link),
                              ),
                            if (canInactivate)
                              IconButton(
                                tooltip:
                                    child.active ? 'Inativar' : 'Reativar',
                                onPressed: () => child.active
                                    ? _confirmInactivate(child)
                                    : _setActive(child, true),
                                icon: Icon(
                                  child.active
                                      ? Icons.block_outlined
                                      : Icons.restore_outlined,
                                ),
                              ),
                          ],
                        ),
                        onTap: () => _editName(child),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _PlacementDraft {
  const _PlacementDraft({this.levelId, this.classId});

  final String? levelId;
  final String? classId;
}

class _SelectPlacementDialog extends StatefulWidget {
  const _SelectPlacementDialog({
    required this.levelRepository,
    required this.classRepository,
    required this.childName,
    this.initialLevelId,
    this.initialClassId,
  });

  final LevelRepository levelRepository;
  final ClassRepository classRepository;
  final String childName;
  final String? initialLevelId;
  final String? initialClassId;

  @override
  State<_SelectPlacementDialog> createState() => _SelectPlacementDialogState();
}

class _SelectPlacementDialogState extends State<_SelectPlacementDialog> {
  late String? _levelId = widget.initialLevelId;
  late String? _classId = widget.initialClassId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nível e turma de ${widget.childName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<List<Level>>(
              stream: widget.levelRepository.watchLevels(activeOnly: true),
              builder: (context, snapshot) {
                final levels = snapshot.data ?? const <Level>[];
                return DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: _levelId,
                  decoration: const InputDecoration(labelText: 'Nível'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sem nível'),
                    ),
                    for (final level in levels)
                      DropdownMenuItem<String?>(
                        value: level.id,
                        child: Text(level.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _levelId = value),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<SchoolClass>>(
              stream: widget.classRepository.watchClasses(activeOnly: true),
              builder: (context, snapshot) {
                final classes = snapshot.data ?? const <SchoolClass>[];
                return DropdownButtonFormField<String?>(
                  // ignore: deprecated_member_use
                  value: _classId,
                  decoration: const InputDecoration(labelText: 'Turma'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sem turma'),
                    ),
                    for (final schoolClass in classes)
                      DropdownMenuItem<String?>(
                        value: schoolClass.id,
                        child: Text(schoolClass.displayLabel),
                      ),
                  ],
                  onChanged: (value) => setState(() => _classId = value),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _PlacementDraft(levelId: _levelId, classId: _classId),
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar nome'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nome'),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _SelectResponsiblesDialog extends StatefulWidget {
  const _SelectResponsiblesDialog({
    required this.userRepository,
    required this.initiallySelected,
    required this.childName,
  });

  final UserRepository userRepository;
  final Set<String> initiallySelected;
  final String childName;

  @override
  State<_SelectResponsiblesDialog> createState() =>
      _SelectResponsiblesDialogState();
}

class _SelectResponsiblesDialogState extends State<_SelectResponsiblesDialog> {
  late final Set<String> _selected = {...widget.initiallySelected};
  String _query = '';

  String _label(UserProfile user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return user.email ?? user.uid;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Responsáveis de ${widget.childName}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar',
                hintText: 'Nome ou e-mail',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<UserProfile>>(
                stream: widget.userRepository.watchManagedUsers(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Não foi possível carregar os responsáveis.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final query = _query.trim().toLowerCase();
                  final responsaveis = snapshot.data!
                      .where((user) => user.role == UserRole.responsavel)
                      .where((user) {
                        if (query.isEmpty) {
                          return true;
                        }
                        final name = (user.displayName ?? '').toLowerCase();
                        final email = (user.email ?? '').toLowerCase();
                        return name.contains(query) || email.contains(query);
                      })
                      .toList(growable: false);

                  if (responsaveis.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhum usuário com papel Responsável.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: responsaveis.length,
                    itemBuilder: (context, index) {
                      final user = responsaveis[index];
                      final checked = _selected.contains(user.uid);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(_label(user)),
                        subtitle: user.email != null ? Text(user.email!) : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(user.uid);
                            } else {
                              _selected.remove(user.uid);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
