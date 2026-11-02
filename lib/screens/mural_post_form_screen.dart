import 'package:flutter/material.dart';

import '../mural/mural_post.dart';
import '../mural/mural_repository.dart';

/// Formulário de criar/editar publicação do mural (gestão+).
class MuralPostFormScreen extends StatefulWidget {
  const MuralPostFormScreen({
    super.key,
    required this.repository,
    required this.authorUid,
    this.existing,
  });

  final MuralPostsRepository repository;
  final String authorUid;
  final MuralPost? existing;

  @override
  State<MuralPostFormScreen> createState() => _MuralPostFormScreenState();
}

class _MuralPostFormScreenState extends State<MuralPostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tituloController;
  late final TextEditingController _textoController;
  late final TextEditingController _localController;
  late final TextEditingController _horarioController;

  late MuralPostKind _kind;
  late DateTime _releasedAt;
  late DateTime _effectiveAt;
  bool _sameEffective = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final now = DateTime.now();
    _tituloController = TextEditingController(text: existing?.title ?? '');
    _textoController = TextEditingController(text: existing?.body ?? '');
    _localController = TextEditingController(text: existing?.location ?? '');
    _horarioController =
        TextEditingController(text: existing?.scheduleText ?? '');
    _kind = existing?.kind ?? MuralPostKind.comunicado;
    _releasedAt = existing?.releasedAt ?? now;
    _effectiveAt = existing?.effectiveAt ?? _releasedAt;
    _sameEffective = existing == null ||
        existing.effectiveAt.isAtSameMomentAs(existing.releasedAt);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _textoController.dispose();
    _localController.dispose();
    _horarioController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool released}) async {
    final initial = released ? _releasedAt : _effectiveAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (released) {
        _releasedAt = selected;
        if (_sameEffective) {
          _effectiveAt = selected;
        }
      } else {
        _effectiveAt = selected;
        _sameEffective = selected.isAtSameMomentAs(_releasedAt);
      }
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);
    final title = _tituloController.text.trim();
    final body = _textoController.text.trim();
    final location = _localController.text.trim();
    final schedule = _horarioController.text.trim();
    final effective = _sameEffective ? _releasedAt : _effectiveAt;

    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.repository.createPost(
          title: title,
          body: body,
          kind: _kind,
          createdBy: widget.authorUid,
          releasedAt: _releasedAt,
          effectiveAt: effective,
          location: location.isEmpty ? null : location,
          scheduleText: schedule.isEmpty ? null : schedule,
        );
      } else {
        await widget.repository.updatePost(
          postId: existing.id,
          updatedBy: widget.authorUid,
          title: title,
          body: body,
          kind: _kind,
          releasedAt: _releasedAt,
          effectiveAt: effective,
          location: location.isEmpty ? null : location,
          scheduleText: schedule.isEmpty ? null : schedule,
          clearLocation: location.isEmpty && existing.location != null,
          clearScheduleText: schedule.isEmpty && existing.scheduleText != null,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar publicação' : 'Nova publicação'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SegmentedButton<MuralPostKind>(
              showSelectedIcon: false,
              segments: [
                for (final kind in MuralPostKind.values)
                  ButtonSegment<MuralPostKind>(
                    value: kind,
                    icon: Icon(kind.icon),
                    label: Text(kind.label),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _tituloController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe um título.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _textoController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Escreva a mensagem da publicação.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _localController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Local (opcional)',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _horarioController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Horários / o que trazer (opcional)',
                prefixIcon: Icon(Icons.schedule_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Liberação'),
              subtitle: Text(formatMuralDateTime(_releasedAt)),
              trailing: TextButton(
                onPressed: () => _pickDateTime(released: true),
                child: const Text('Alterar'),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Efetividade igual à liberação'),
              subtitle: const Text(
                'Desative para ancorar o item em outra data na timeline.',
              ),
              value: _sameEffective,
              onChanged: (v) => setState(() {
                _sameEffective = v;
                if (v) _effectiveAt = _releasedAt;
              }),
            ),
            if (!_sameEffective)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timeline),
                title: const Text('Efetividade'),
                subtitle: Text(formatMuralDateTime(_effectiveAt)),
                trailing: TextButton(
                  onPressed: () => _pickDateTime(released: false),
                  child: const Text('Alterar'),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(editing ? 'Salvar alterações' : 'Publicar no mural'),
            ),
          ],
        ),
      ),
    );
  }
}

String formatMuralDateTime(DateTime value) {
  final local = value.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$d/$m/${local.year} $h:$min';
}

String formatMuralDate(DateTime value) {
  final local = value.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  return '$d/$m/${local.year}';
}
