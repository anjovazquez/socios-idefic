import 'package:flutter/material.dart';

import '../../domain/season/season.dart';
import '../format/money.dart';

/// Shared shape of a dialog that submits and shows its error inline.
class _SubmitDialog extends StatefulWidget {
  const _SubmitDialog({
    required this.title,
    required this.action,
    required this.saveKey,
    required this.builder,
    required this.onSubmit,
  });

  final String title;
  final String action;
  final Key saveKey;
  final List<Widget> Function(BuildContext context, VoidCallback refresh)
  builder;
  final Future<String> Function() onSubmit;

  @override
  State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> {
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final confirmation = await widget.onSubmit();
      if (mounted) Navigator.of(context).pop(confirmation);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...widget.builder(context, () => setState(() {})),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: widget.saveKey,
          onPressed: _saving ? null : _save,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// New season: name suggested after the newest one; dates by default
/// 1 September – 31 August.
class NewSeasonDialog extends StatefulWidget {
  const NewSeasonDialog({
    super.key,
    required this.suggestedName,
    required this.onSubmit,
  });

  final String suggestedName;
  final Future<String> Function(String name) onSubmit;

  @override
  State<NewSeasonDialog> createState() => _NewSeasonDialogState();
}

class _NewSeasonDialogState extends State<NewSeasonDialog> {
  late final _name = TextEditingController(text: widget.suggestedName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SubmitDialog(
    title: 'Nueva temporada',
    action: 'Crear',
    saveKey: const Key('new-season-save'),
    onSubmit: () => widget.onSubmit(_name.text),
    builder: (context, _) => [
      TextField(
        key: const Key('new-season-name'),
        controller: _name,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          helperText: 'Del 1 de septiembre al 31 de agosto',
        ),
      ),
    ],
  );
}

/// Activates a season with its ordinary fee (RF-008).
class ActivateSeasonDialog extends StatefulWidget {
  const ActivateSeasonDialog({
    super.key,
    required this.season,
    required this.currentActive,
    required this.onSubmit,
  });

  final Season season;
  final Season? currentActive;
  final Future<String> Function(String fee) onSubmit;

  @override
  State<ActivateSeasonDialog> createState() => _ActivateSeasonDialogState();
}

class _ActivateSeasonDialogState extends State<ActivateSeasonDialog> {
  late final _fee = TextEditingController(
    text: switch (widget.season.defaultFeeCents ??
        widget.currentActive?.defaultFeeCents) {
      final int cents => centsToInput(cents),
      _ => '',
    },
  );

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.currentActive;
    final isActive = widget.season.status == SeasonStatus.active;
    return _SubmitDialog(
      title: isActive
          ? 'Cuota de ${widget.season.name}'
          : 'Activar ${widget.season.name}',
      action: isActive ? 'Guardar' : 'Activar',
      saveKey: const Key('activate-season-save'),
      onSubmit: () => widget.onSubmit(_fee.text),
      builder: (context, _) => [
        TextField(
          key: const Key('activate-season-fee'),
          controller: _fee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cuota ordinaria',
            suffixText: '€',
            helperText: 'Es la cuota propuesta para todos los socios',
          ),
        ),
        if (!isActive && previous != null && previous.id != widget.season.id)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${previous.name} dejará de ser la temporada activa y pasará a '
              'temporadas anteriores.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}
