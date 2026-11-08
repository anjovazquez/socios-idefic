import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/member/club_member.dart';

/// Edits the member number (RF-006). [onSubmit] returns the confirmation or
/// throws the error message.
class MemberNumberDialog extends StatefulWidget {
  const MemberNumberDialog({
    super.key,
    required this.member,
    required this.onSubmit,
  });

  final ClubMember member;
  final Future<String> Function(String number) onSubmit;

  @override
  State<MemberNumberDialog> createState() => _MemberNumberDialogState();
}

class _MemberNumberDialogState extends State<MemberNumberDialog> {
  late final _number = TextEditingController(
    text: widget.member.memberNumber?.toString(),
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final confirmation = await widget.onSubmit(_number.text);
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
      title: const Text('Número de socio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.member.displayName, style: theme.textTheme.bodyMedium),
          TextField(
            key: const Key('member-number-field'),
            controller: _number,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Número'),
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
          key: const Key('member-number-save'),
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
