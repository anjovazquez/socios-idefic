import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../club/image_picking.dart';
import '../session/session_view_model.dart';
import 'my_data_view_model.dart';

/// «Mis datos» (RF-005).
class MyDataPage extends StatelessWidget {
  const MyDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyDataViewModel(
        context.read<AppUseCases>(),
        pickImage: context.read<PickImage>(),
      )..load(),
      child: const _MyDataView(),
    );
  }
}

class _MyDataView extends StatelessWidget {
  const _MyDataView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyDataViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis datos'),
        // A bottom bar section (ClubShell): no back button.
        automaticallyImplyLeading: false,
      ),
      body: switch (viewModel.profile) {
        null when viewModel.isLoading => const Center(
          child: CircularProgressIndicator(),
        ),
        null => Center(child: Text(viewModel.error ?? '')),
        _ => const _MyDataForm(),
      },
    );
  }
}

class _MyDataForm extends StatefulWidget {
  const _MyDataForm();

  @override
  State<_MyDataForm> createState() => _MyDataFormState();
}

class _MyDataFormState extends State<_MyDataForm> {
  late final _profile = context.read<MyDataViewModel>().profile!;
  late final _firstName = TextEditingController(text: _profile.firstName);
  late final _lastName = TextEditingController(text: _profile.lastName);
  late final _phone = TextEditingController(text: _profile.phone);
  late DateTime? _birthDate = _profile.birthDate;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await context.read<MyDataViewModel>().save(
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
      birthDate: _birthDate,
    );
    if (saved) {
      messenger.showSnackBar(const SnackBar(content: Text('Datos guardados')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MyDataViewModel>();
    final club = context.watch<SessionViewModel>().activeClub;
    final theme = Theme.of(context);
    final birthDate = _birthDate;
    final photoUrl = viewModel.photoUrl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Semantics(
            label: 'Tu foto',
            child: CircleAvatar(
              key: const Key('my-data-photo'),
              radius: 48,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
              onBackgroundImageError: photoUrl == null ? null : (_, _) {},
              child: photoUrl == null
                  ? Icon(
                      Icons.person,
                      size: 48,
                      color: theme.colorScheme.onPrimaryContainer,
                    )
                  : null,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              key: const Key('my-data-change-photo'),
              onPressed: viewModel.isBusy ? null : viewModel.changePhoto,
              child: Text(photoUrl == null ? 'Añadir foto' : 'Cambiar foto'),
            ),
            if (photoUrl != null)
              TextButton(
                onPressed: viewModel.isBusy ? null : viewModel.removePhoto,
                child: const Text('Quitar foto'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.mail_outline),
          title: Text(_profile.email, key: const Key('my-data-email')),
          subtitle: const Text('Es tu acceso a la app y no se puede cambiar'),
        ),
        if (club?.memberNumber case final number?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.badge_outlined),
            title: Text('Socio nº $number'),
            subtitle: Text(club!.name),
          ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('my-data-first-name'),
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        TextField(
          key: const Key('my-data-last-name'),
          controller: _lastName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Apellidos'),
        ),
        TextField(
          key: const Key('my-data-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
        ),
        ListTile(
          key: const Key('my-data-birth-date'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Fecha de nacimiento (opcional)'),
          subtitle: Text(
            birthDate == null
                ? 'Sin indicar'
                : '${birthDate.day.toString().padLeft(2, '0')}/'
                      '${birthDate.month.toString().padLeft(2, '0')}/'
                      '${birthDate.year}',
          ),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _pickBirthDate,
        ),
        if (viewModel.error case final error?) ...[
          const SizedBox(height: 8),
          Text(
            error,
            key: const Key('my-data-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('my-data-save'),
          onPressed: viewModel.isBusy ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
