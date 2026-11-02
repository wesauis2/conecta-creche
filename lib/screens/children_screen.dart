import 'package:flutter/material.dart';

import '../presence/child.dart';
import '../presence/child_repository.dart';
import '../users/user_profile.dart';

/// Catálogo de crianças, separado da lista operacional de presença. See
/// CONTEXT.md "Gestão de crianças" / "Inativação de criança".
class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({
    super.key,
    required this.profile,
    required this.childRepository,
  });

  final UserProfile profile;
  final ChildRepository childRepository;

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

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            itemCount: children.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final child = children[index];
              return ListTile(
                title: Text(child.name),
                subtitle: child.active ? null : const Text('Inativa'),
                leading: CircleAvatar(
                  child: Text(
                    child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                  ),
                ),
                trailing: canInactivate
                    ? IconButton(
                        tooltip: child.active ? 'Inativar' : 'Reativar',
                        onPressed: () => child.active
                            ? _confirmInactivate(child)
                            : _setActive(child, true),
                        icon: Icon(
                          child.active
                              ? Icons.block_outlined
                              : Icons.restore_outlined,
                        ),
                      )
                    : null,
                onTap: () => _editName(child),
              );
            },
          );
        },
      ),
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
