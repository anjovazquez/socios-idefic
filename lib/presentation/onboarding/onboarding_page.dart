import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../session/session_view_model.dart';
import 'onboarding_view_model.dart';
import 'terms_text.dart';

/// First access of an invited member (RF-003).
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionViewModel>();
    final status = session.onboarding;
    if (status == null) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      create: (context) => OnboardingViewModel(
        context.read<AppUseCases>(),
        status: status,
        onCompleted: session.loadClubs,
      ),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);
    final steps = viewModel.steps;
    final index = steps.indexOf(viewModel.step);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activa tu cuenta'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: context.read<SessionViewModel>().signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paso ${index + 1} de ${steps.length}',
                    key: const Key('onboarding-progress'),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: (index + 1) / steps.length),
                  const SizedBox(height: 24),
                  switch (viewModel.step) {
                    OnboardingStep.password => const _PasswordStep(),
                    OnboardingStep.personalData => const _PersonalDataStep(),
                    OnboardingStep.terms => const _TermsStep(),
                  },
                  if (viewModel.error case final error?) ...[
                    const SizedBox(height: 16),
                    Text(
                      error,
                      key: const Key('onboarding-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStep extends StatefulWidget {
  const _PasswordStep();

  @override
  State<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<_PasswordStep> {
  final _password = TextEditingController();
  final _repeated = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _repeated.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Crea tu contraseña', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'La usarás con ${viewModel.status.email} para entrar en tu club.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('onboarding-password'),
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            helperText: 'Mínimo 8 caracteres, con letras y números',
          ),
        ),
        TextField(
          key: const Key('onboarding-password-repeat'),
          controller: _repeated,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Repite la contraseña'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('onboarding-password-next'),
          onPressed: viewModel.isBusy
              ? null
              : () => viewModel.submitPassword(_password.text, _repeated.text),
          child: const Text('Continuar'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('onboarding-google'),
          onPressed: viewModel.isBusy
              ? null
              : context.read<AppUseCases>().signInWithGoogle.call,
          icon: const Icon(Icons.account_circle_outlined),
          label: const Text('Prefiero entrar con Google'),
        ),
      ],
    );
  }
}

class _PersonalDataStep extends StatefulWidget {
  const _PersonalDataStep();

  @override
  State<_PersonalDataStep> createState() => _PersonalDataStepState();
}

class _PersonalDataStepState extends State<_PersonalDataStep> {
  late final OnboardingViewModel _viewModel = context
      .read<OnboardingViewModel>();
  late final _firstName = TextEditingController(
    text: _viewModel.status.firstName,
  );
  late final _lastName = TextEditingController(
    text: _viewModel.status.lastName,
  );
  late final _phone = TextEditingController(text: _viewModel.status.phone);
  late DateTime? _birthDate = _viewModel.status.birthDate;

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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);
    final birthDate = _birthDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tus datos', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Tu club los usará para tu carnet y para comunicarse contigo.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('onboarding-first-name'),
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        TextField(
          key: const Key('onboarding-last-name'),
          controller: _lastName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Apellidos'),
        ),
        TextField(
          key: const Key('onboarding-phone'),
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
        ),
        const SizedBox(height: 8),
        ListTile(
          key: const Key('onboarding-birth-date'),
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
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('onboarding-data-next'),
          onPressed: viewModel.isBusy
              ? null
              : () => viewModel.submitPersonalData(
                  firstName: _firstName.text,
                  lastName: _lastName.text,
                  phone: _phone.text,
                  birthDate: _birthDate,
                ),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

class _TermsStep extends StatefulWidget {
  const _TermsStep();

  @override
  State<_TermsStep> createState() => _TermsStepState();
}

class _TermsStepState extends State<_TermsStep> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(termsTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Text(termsBody.trim(), style: theme.textTheme.bodyMedium),
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const Key('onboarding-accept'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _accepted,
          onChanged: (value) => setState(() => _accepted = value ?? false),
          title: const Text('He leído y acepto las condiciones de uso'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('onboarding-finish'),
          onPressed: viewModel.isBusy
              ? null
              : () => viewModel.accept(accepted: _accepted),
          child: const Text('Aceptar y entrar'),
        ),
        TextButton(
          onPressed: viewModel.isBusy ? null : viewModel.backToPersonalData,
          child: const Text('Volver a mis datos'),
        ),
      ],
    );
  }
}
