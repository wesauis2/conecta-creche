import 'package:flutter/material.dart';

import '../auth/google_auth_service.dart';
import '../users/user_profile.dart';
import '../users/user_repository.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.profile,
    required this.authService,
    required this.userRepository,
  });

  final UserProfile profile;
  final GoogleAuthService authService;
  final UserRepository userRepository;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _emailController;
  bool _saving = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName ?? '',
    );
    _emailController = TextEditingController(text: widget.profile.email ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await widget.userRepository.updateDisplayName(
        widget.profile.uid,
        displayName,
      );
      if (mounted) {
        setState(() => _successMessage = 'Perfil atualizado com sucesso.');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Seus dados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Nome de exibição',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            TextField(
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'E-mail',
                border: const OutlineInputBorder(),
                helperText: 'O e-mail não pode ser alterado.',
                helperStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              controller: _emailController,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Perfil de acesso',
                border: OutlineInputBorder(),
              ),
              child: Text(widget.profile.role.label),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar alterações'),
            ),
            if (_successMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _successMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: widget.authService.signOut,
              child: const Text('Sair'),
            ),
          ],
        ),
      ),
    );
  }
}
