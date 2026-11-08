import 'package:flutter/material.dart';

/// Sign-up form with the minimum data of RF-002 (name and email).
/// [onSubmit] returns the confirmation or throws the error message.
class NewMemberDialog extends StatefulWidget {
  const NewMemberDialog({super.key, required this.onSubmit});

  final Future<String> Function(String firstName, String email) onSubmit;

  @override
  State<NewMemberDialog> createState() => _NewMemberDialogState();
}

class _NewMemberDialogState extends State<NewMemberDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final confirmation = await widget.onSubmit(_name.text, _email.text);
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
      title: const Text('Nuevo socio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Le enviaremos un email para que active su cuenta.',
            style: theme.textTheme.bodyMedium,
          ),
          TextField(
            key: const Key('new-member-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          TextField(
            key: const Key('new-member-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            onSubmitted: (_) => _save(),
          ),
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
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('new-member-save'),
          onPressed: _saving ? null : _save,
          child: const Text('Dar de alta'),
        ),
      ],
    );
  }
}
