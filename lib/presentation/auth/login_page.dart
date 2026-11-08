import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session/session_view_model.dart';
import 'login_view_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<SessionViewModel>().clearSignInFailure();
    context.read<LoginViewModel>().submit(
      email: _email.text,
      password: _password.text,
    );
  }

  void _signInWithGoogle() {
    context.read<SessionViewModel>().clearSignInFailure();
    context.read<LoginViewModel>().signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final redirectFailure = context.watch<SessionViewModel>().signInFailure;
    final errorMessage =
        viewModel.errorMessage ??
        (redirectFailure == null
            ? null
            : LoginViewModel.messageFor(redirectFailure));
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Socios', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Entra con el email con el que te dio de alta tu club.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('login-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('login-password'),
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                    ),
                    if (errorMessage case final message?) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: viewModel.isSubmitting ? null : _submit,
                      child: viewModel.isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('login-google'),
                      onPressed: viewModel.isSubmitting
                          ? null
                          : _signInWithGoogle,
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('Continuar con Google'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '¿Aún no tienes cuenta? Tu club te enviará una invitación '
                      'por email.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
