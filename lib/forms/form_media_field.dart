import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'form_media_answer.dart';
import 'form_question.dart';

/// Fonte injetável de bytes brutos (galeria/arquivo). Testes e o app podem
/// substituir; sem fonte, o botão informa que o seletor não está disponível.
typedef FormMediaBytesPicker = Future<FormMediaPick?> Function(
  FormQuestionKind kind,
);

class FormMediaPick {
  const FormMediaPick({
    required this.bytes,
    this.mime,
  });

  final Uint8List bytes;
  final String? mime;
}

/// Porta global opcional (ex.: galeria no bootstrap). Preferir [picker] no widget.
FormMediaBytesPicker? formMediaBytesPickerOverride;

/// Campo de anexo para kinds imagem/áudio/vídeo: copy Spark, teto e valor
/// estruturado [FormMediaAnswer].
class FormMediaField extends StatefulWidget {
  const FormMediaField({
    super.key,
    required this.kind,
    required this.value,
    required this.onChanged,
    this.picker,
    this.enabled = true,
  });

  final FormQuestionKind kind;
  final FormMediaAnswer? value;
  final ValueChanged<FormMediaAnswer?> onChanged;
  final FormMediaBytesPicker? picker;
  final bool enabled;

  @override
  State<FormMediaField> createState() => _FormMediaFieldState();
}

class _FormMediaFieldState extends State<FormMediaField> {
  String? _error;
  bool _busy = false;

  FormMediaBytesPicker? get _effectivePicker =>
      widget.picker ?? formMediaBytesPickerOverride;

  Future<void> _attach() async {
    final picker = _effectivePicker;
    if (picker == null) {
      setState(() {
        _error =
            'Seletor de mídia não configurado neste ambiente. '
            'O anexo precisa caber em ~${(kFormMediaMaxBytes / 1024).round()} KiB.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pick = await picker(widget.kind);
      if (pick == null || !mounted) {
        return;
      }
      final encoded = FormMediaCodec.encodeForKind(
        kind: widget.kind,
        bytes: pick.bytes,
        mime: pick.mime,
      );
      widget.onChanged(encoded);
    } on FormMediaTooLargeException catch (e) {
      setState(() {
        _error =
            'Anexo acima do teto (~${(e.maxBytes / 1024).round()} KiB após '
            'compressão). Use arquivo menor ou texto.';
      });
      widget.onChanged(null);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      widget.onChanged(null);
    } on Object catch (e) {
      setState(() => _error = 'Não foi possível anexar: $e');
      widget.onChanged(null);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    final attachLabel = switch (widget.kind) {
      FormQuestionKind.image => 'Anexar imagem',
      FormQuestionKind.audio => 'Anexar áudio',
      FormQuestionKind.video => 'Anexar vídeo',
      _ => 'Anexar',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          kFormMediaSparkNotice,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (widget.kind == FormQuestionKind.audio ||
            widget.kind == FormQuestionKind.video) ...[
          const SizedBox(height: 6),
          Text(
            kFormMediaAvDiscourageNotice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (value != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              value.displayLabel,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: !widget.enabled || _busy ? null : _attach,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              label: Text(attachLabel),
            ),
            if (value != null)
              TextButton(
                onPressed: !widget.enabled || _busy
                    ? null
                    : () {
                        setState(() => _error = null);
                        widget.onChanged(null);
                      },
                child: const Text('Remover'),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
