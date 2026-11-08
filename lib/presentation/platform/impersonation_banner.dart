import 'package:flutter/material.dart';

/// Persistent notice while the platform admin manages a club that is not
/// theirs (§17): everything done is recorded under their name.
class ImpersonationBanner extends StatelessWidget {
  const ImpersonationBanner({
    super.key,
    required this.clubName,
    required this.onExit,
  });

  final String clubName;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: const Key('impersonation-banner'),
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Estás administrando $clubName como administrador de la '
                  'plataforma. Lo que hagas queda registrado a tu nombre.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
              TextButton(
                key: const Key('impersonation-exit'),
                onPressed: onExit,
                child: const Text('Salir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
