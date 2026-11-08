import 'package:flutter/material.dart';

import '../../domain/platform/platform_club.dart';

/// Values typed in the club form. Admin fields only when creating.
class ClubFormValues {
  const ClubFormValues({
    required this.name,
    required this.code,
    this.adminEmail = '',
    this.adminName = '',
  });

  final String name;
  final String code;
  final String adminEmail;
  final String adminName;
}

/// Create (club == null) or edit a club. [onSubmit] returns an error message
/// to show, or null to close the dialog.
class ClubFormDialog extends StatefulWidget {
  const ClubFormDialog({super.key, this.club, required this.onSubmit});

  final PlatformClub? club;
  final Future<String?> Function(ClubFormValues values) onSubmit;

  @override
  State<ClubFormDialog> createState() => _ClubFormDialogState();
}

class _ClubFormDialogState extends State<ClubFormDialog> {
  late final _name = TextEditingController(text: widget.club?.name);
  late final _code = TextEditingController(text: widget.club?.code);
  final _adminEmail = TextEditingController();
  final _adminName = TextEditingController();
  String? _error;
  bool _saving = false;

  bool get _isNew => widget.club == null;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _adminEmail.dispose();
    _adminName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      ClubFormValues(
        name: _name.text,
        code: _code.text,
        adminEmail: _adminEmail.text,
        adminName: _adminName.text,
      ),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_isNew ? 'Nuevo club' : 'Editar club'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('club-form-name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre del club'),
            ),
            TextField(
              key: const Key('club-form-code'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código',
                helperText: 'Identificador corto, p. ej. IDEFIC',
              ),
            ),
            if (_isNew) ...[
              TextField(
                key: const Key('club-form-admin-email'),
                controller: _adminEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email del administrador',
                ),
              ),
              TextField(
                key: const Key('club-form-admin-name'),
                controller: _adminName,
                decoration: const InputDecoration(
                  labelText: 'Nombre del administrador (opcional)',
                ),
              ),
            ],
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
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('club-form-save'),
          onPressed: _saving ? null : _save,
          child: Text(_isNew ? 'Crear club' : 'Guardar'),
        ),
      ],
    );
  }
}
