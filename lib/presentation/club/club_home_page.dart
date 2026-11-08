import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../session/session_view_model.dart';
import 'club_avatar.dart';

/// Minimal club home. Sections (blog, carnet, ...) arrive in later slices.
class ClubHomePage extends StatelessWidget {
  const ClubHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final club = session.activeClub;
    if (club == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(club.name),
        actions: [
          if (session.isPlatformAdmin)
            IconButton(
              key: const Key('open-platform'),
              tooltip: 'Plataforma',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: session.openPlatform,
            ),
          if (club.canAdminister)
            IconButton(
              key: const Key('open-settings'),
              tooltip: 'Configuración del club',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.go('/club/settings'),
            ),
          if (session.canSwitchClub)
            IconButton(
              key: const Key('switch-club'),
              tooltip: 'Cambiar de club',
              icon: const Icon(Icons.swap_horiz),
              onPressed: session.openClubSelector,
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: session.signOut,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClubAvatar(
              name: club.name,
              logoUrl: club.logoUrl,
              primaryColor: club.primaryColor,
              radius: 40,
            ),
            const SizedBox(height: 16),
            Text(club.name, style: theme.textTheme.headlineSmall),
            if (club.memberNumber != null) ...[
              const SizedBox(height: 4),
              Text(
                'Socio nº ${club.memberNumber}',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
