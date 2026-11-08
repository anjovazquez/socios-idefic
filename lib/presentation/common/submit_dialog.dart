import 'package:flutter/material.dart';

/// Dialog that submits a form and shows its error inline (DESIGN.md §6).
/// [onSubmit] returns the confirmation to show, or throws the message.
class SubmitDialog extends StatefulWidget {
  const SubmitDialog({
    super.key,
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
  State<SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<SubmitDialog> {
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
