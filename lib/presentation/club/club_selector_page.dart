import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session/session_view_model.dart';
import 'club_avatar.dart';

class ClubSelectorPage extends StatelessWidget {
  const ClubSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige tu club'),
        actions: [
          if (session.isPlatformAdmin)
            IconButton(
              key: const Key('open-platform'),
              tooltip: 'Plataforma',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: session.openPlatform,
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: session.signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final club in session.clubs)
            ListTile(
              key: Key('club-${club.code}'),
              leading: ClubAvatar(
                name: club.name,
                logoUrl: club.logoUrl,
                primaryColor: club.primaryColor,
              ),
              title: Text(club.name),
              subtitle: club.memberNumber == null
                  ? null
                  : Text('Socio nº ${club.memberNumber}'),
              trailing: club.id == session.activeClub?.id
                  ? const Icon(Icons.check)
                  : const Icon(Icons.chevron_right),
              onTap: () => session.selectClub(club.id),
            ),
        ],
      ),
    );
  }
}
