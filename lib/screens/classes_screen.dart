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

/// CRUD de turmas (gestão+). Sala como texto opcional na v1.
/// Ver CONTEXT.md "Turma".
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({
    super.key,
    required this.profile,
    required this.classRepository,
    required this.levelRepository,
    required this.childRepository,
    required this.userRepository,
  });

  final UserProfile profile;
  final ClassRepository classRepository;
  final LevelRepository levelRepository;
  final ChildRepository childRepository;
  final UserRepository userRepository;

  Future<void> _openEditor(
    BuildContext context, {
    SchoolClass? existing,
  }) async {
    final result = await showDialog<_ClassDraft>(
      context: context,
      builder: (context) => _ClassEditorDialog(
        initial: existing,
        levelRepository: levelRepository,
        childRepository: childRepository,
        userRepository: userRepository,
      ),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      if (existing == null) {
        await classRepository.createClass(
          year: result.year,
          levelIds: result.levelIds,
          room: result.room,
          caregiverUids: result.caregiverUids,
          childIds: result.childIds,
          active: result.active,
          createdBy: profile.uid,
        );
      } else {
        await classRepository.updateClass(
          classId: existing.id,
          year: result.year,
          levelIds: result.levelIds,
          room: result.room,
          clearRoom: result.room == null || result.room!.trim().isEmpty,
          caregiverUids: result.caregiverUids,
          childIds: result.childIds,
          active: result.active,
          updatedBy: profile.uid,
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    }
  }

  Future<void> _setActive(
    BuildContext context,
    SchoolClass schoolClass,
    bool active,
  ) async {
    try {
      await classRepository.updateClass(
        classId: schoolClass.id,
        active: active,
        updatedBy: profile.uid,
      );
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!profile.role.canManageLevelsAndClasses) {
      return Scaffold(
        appBar: AppBar(title: const Text('Turmas')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Você não tem permissão para gerenciar turmas.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Turmas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        tooltip: 'Nova turma',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<SchoolClass>>(
        stream: classRepository.watchClasses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as turmas.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final classes = snapshot.data!;
          if (classes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma turma cadastrada.\nToque em + para adicionar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return StreamBuilder<List<Level>>(
            stream: levelRepository.watchLevels(),
            builder: (context, levelsSnap) {
              final levelsById = <String, Level>{
                for (final level in levelsSnap.data ?? const <Level>[])
                  level.id: level,
              };

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                itemCount: classes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final schoolClass = classes[index];
                  final levelNames = schoolClass.levelIds
                      .map((id) => levelsById[id]?.name ?? id)
                      .join(', ');
                  final subtitleParts = <String>[
                    if (!schoolClass.active) 'Inativa',
                    if (levelNames.isNotEmpty) levelNames,
                    '${schoolClass.childIds.length} criança'
                        '${schoolClass.childIds.length == 1 ? '' : 's'}',
                    '${schoolClass.caregiverUids.length} cuidador'
                        '${schoolClass.caregiverUids.length == 1 ? '' : 'es'}',
                  ];
                  return ListTile(
                    title: Text(schoolClass.displayLabel),
                    subtitle: Text(subtitleParts.join(' · ')),
                    trailing: IconButton(
                      tooltip: schoolClass.active ? 'Inativar' : 'Reativar',
                      onPressed: () =>
                          _setActive(context, schoolClass, !schoolClass.active),
                      icon: Icon(
                        schoolClass.active
                            ? Icons.block_outlined
                            : Icons.restore_outlined,
                      ),
                    ),
                    onTap: () => _openEditor(context, existing: schoolClass),
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

class _ClassDraft {
  const _ClassDraft({
    required this.year,
    required this.levelIds,
    required this.room,
    required this.caregiverUids,
    required this.childIds,
    required this.active,
  });

  final int year;
  final List<String> levelIds;
  final String? room;
  final List<String> caregiverUids;
  final List<String> childIds;
  final bool active;
}

class _ClassEditorDialog extends StatefulWidget {
  const _ClassEditorDialog({
    this.initial,
    required this.levelRepository,
    required this.childRepository,
    required this.userRepository,
  });

  final SchoolClass? initial;
  final LevelRepository levelRepository;
  final ChildRepository childRepository;
  final UserRepository userRepository;

  @override
  State<_ClassEditorDialog> createState() => _ClassEditorDialogState();
}

class _ClassEditorDialogState extends State<_ClassEditorDialog> {
  late final TextEditingController _yearController;
  late final TextEditingController _roomController;
  late final Set<String> _levelIds;
  late final Set<String> _caregiverUids;
  late final Set<String> _childIds;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _yearController = TextEditingController(
      text: '${initial?.year ?? DateTime.now().year}',
    );
    _roomController = TextEditingController(text: initial?.room ?? '');
    _levelIds = {...?initial?.levelIds};
    _caregiverUids = {...?initial?.caregiverUids};
    _childIds = {...?initial?.childIds};
    _active = initial?.active ?? true;
  }

  @override
  void dispose() {
    _yearController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _submit() {
    final year = int.tryParse(_yearController.text.trim());
    if (year == null || year < 2000 || year > 2100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um ano letivo válido.')),
      );
      return;
    }
    final room = _roomController.text.trim();
    Navigator.of(context).pop(
      _ClassDraft(
        year: year,
        levelIds: _levelIds.toList(growable: false),
        room: room.isEmpty ? null : room,
        caregiverUids: _caregiverUids.toList(growable: false),
        childIds: _childIds.toList(growable: false),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nova turma' : 'Editar turma'),
      content: SizedBox(
        width: double.maxFinite,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Ano letivo'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Sala (opcional)',
                  hintText: 'Ex.: Sala A, Bloco 2',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativa'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              const SizedBox(height: 8),
              Text('Níveis', style: Theme.of(context).textTheme.titleSmall),
              StreamBuilder<List<Level>>(
                stream: widget.levelRepository.watchLevels(activeOnly: true),
                builder: (context, snapshot) {
                  final levels = snapshot.data ?? const <Level>[];
                  if (levels.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Cadastre níveis ativos primeiro.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final level in levels)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _levelIds.contains(level.id),
                          title: Text(level.name),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _levelIds.add(level.id);
                              } else {
                                _levelIds.remove(level.id);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text('Cuidadores', style: Theme.of(context).textTheme.titleSmall),
              StreamBuilder<List<UserProfile>>(
                stream: widget.userRepository.watchManagedUsers(),
                builder: (context, snapshot) {
                  final caregivers = (snapshot.data ?? const <UserProfile>[])
                      .where((user) => user.role.canOperatePresence)
                      .toList(growable: false);
                  if (caregivers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nenhum cuidador+ disponível.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final user in caregivers)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _caregiverUids.contains(user.uid),
                          title: Text(
                            user.displayName?.trim().isNotEmpty == true
                                ? user.displayName!.trim()
                                : (user.email ?? user.uid),
                          ),
                          subtitle: Text(user.role.label),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _caregiverUids.add(user.uid);
                              } else {
                                _caregiverUids.remove(user.uid);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text('Crianças', style: Theme.of(context).textTheme.titleSmall),
              StreamBuilder<List<Child>>(
                stream: widget.childRepository.watchChildren(activeOnly: true),
                builder: (context, snapshot) {
                  final children = snapshot.data ?? const <Child>[];
                  if (children.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nenhuma criança ativa cadastrada.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final child in children)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _childIds.contains(child.id),
                          title: Text(child.name),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _childIds.add(child.id);
                              } else {
                                _childIds.remove(child.id);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
