import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'session_view_model.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({required this.title, required this.message, this.action});

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.read<SessionViewModel>();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ?action,
              TextButton(
                onPressed: session.signOut,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoClubsPage extends StatelessWidget {
  const NoClubsPage({super.key});

  @override
  Widget build(BuildContext context) => const _MessagePage(
    title: 'Todavía no tienes ningún club',
    message:
        'Cuando tu club te dé de alta como socio, lo verás aquí con esta misma '
        'cuenta.',
  );
}

class SessionErrorPage extends StatelessWidget {
  const SessionErrorPage({super.key});

  @override
  Widget build(BuildContext context) => _MessagePage(
    title: 'No hemos podido cargar tus clubes',
    message: 'Comprueba tu conexión e inténtalo de nuevo.',
    action: FilledButton(
      onPressed: context.read<SessionViewModel>().loadClubs,
      child: const Text('Reintentar'),
    ),
  );
}
