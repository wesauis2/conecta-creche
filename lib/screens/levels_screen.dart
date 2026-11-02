import 'package:flutter/material.dart';

import '../levels/level.dart';
import '../levels/level_repository.dart';
import '../users/user_profile.dart';

/// CRUD de níveis (gestão+). Ver CONTEXT.md "Nível".
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({
    super.key,
    required this.profile,
    required this.levelRepository,
  });

  final UserProfile profile;
  final LevelRepository levelRepository;

  Future<void> _openEditor(
    BuildContext context, {
    Level? existing,
  }) async {
    final result = await showDialog<_LevelDraft>(
      context: context,
      builder: (context) => _LevelEditorDialog(initial: existing),
    );
    if (result == null || !context.mounted) {
      return;
    }

    try {
      if (existing == null) {
        await levelRepository.createLevel(
          name: result.name,
          active: result.active,
          createdBy: profile.uid,
        );
      } else {
        await levelRepository.updateLevel(
          levelId: existing.id,
          name: result.name,
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
    Level level,
    bool active,
  ) async {
    try {
      await levelRepository.updateLevel(
        levelId: level.id,
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
        appBar: AppBar(title: const Text('Níveis')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Você não tem permissão para gerenciar níveis.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Níveis')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        tooltip: 'Novo nível',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Level>>(
        stream: levelRepository.watchLevels(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar os níveis.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final levels = snapshot.data!;
          if (levels.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum nível cadastrado.\nToque em + para adicionar.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            itemCount: levels.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final level = levels[index];
              return ListTile(
                title: Text(level.name),
                subtitle: Text(
                  level.active ? 'Ativo · ordem ${level.sortIndex}' : 'Inativo',
                ),
                trailing: IconButton(
                  tooltip: level.active ? 'Inativar' : 'Reativar',
                  onPressed: () => _setActive(context, level, !level.active),
                  icon: Icon(
                    level.active
                        ? Icons.block_outlined
                        : Icons.restore_outlined,
                  ),
                ),
                onTap: () => _openEditor(context, existing: level),
              );
            },
          );
        },
      ),
    );
  }
}

class _LevelDraft {
  const _LevelDraft({required this.name, required this.active});

  final String name;
  final bool active;
}

class _LevelEditorDialog extends StatefulWidget {
  const _LevelEditorDialog({this.initial});

  final Level? initial;

  @override
  State<_LevelEditorDialog> createState() => _LevelEditorDialogState();
}

class _LevelEditorDialogState extends State<_LevelEditorDialog> {
  late final TextEditingController _nameController;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _active = widget.initial?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(_LevelDraft(name: name, active: _active));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Novo nível' : 'Editar nível'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Ex.: Berçário, Maternal, Nível 1',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativo'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
        ],
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
