import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../users/user_repository.dart';

class UserSyncGate extends StatefulWidget {
  const UserSyncGate({
    super.key,
    required this.user,
    required this.userRepository,
    required this.child,
  });

  final User user;
  final UserRepository userRepository;
  final Widget child;

  @override
  State<UserSyncGate> createState() => _UserSyncGateState();
}

class _UserSyncGateState extends State<UserSyncGate> {
  Object? _syncError;

  @override
  void initState() {
    super.initState();
    _syncUser();
  }

  @override
  void didUpdateWidget(covariant UserSyncGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _syncUser();
    }
  }

  Future<void> _syncUser() async {
    setState(() => _syncError = null);

    try {
      await widget.userRepository.upsertFromFirebaseUser(widget.user);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _syncError = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_syncError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conecta Creche')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Não foi possível sincronizar seu perfil no Firestore.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _syncError.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _syncUser,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
