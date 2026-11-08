import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/platform/platform_club.dart';
import '../session/session_view_model.dart';
import 'club_form_dialog.dart';
import 'platform_view_model.dart';

/// Platform administration: every club of the platform (§17 Clubes).
class PlatformClubsPage extends StatelessWidget {
  const PlatformClubsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionViewModel>();
    return ChangeNotifierProvider(
      create: (context) => PlatformViewModel(
        context.read<AppUseCases>(),
        onClubsChanged: session.refreshClubs,
      )..load(),
      child: const _PlatformClubsView(),
    );
  }
}

class _PlatformClubsView extends StatelessWidget {
  const _PlatformClubsView();

  Future<void> _showForm(BuildContext context, {PlatformClub? club}) async {
    final viewModel = context.read<PlatformViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ClubFormDialog(
        club: club,
        onSubmit: (values) => club == null
            ? viewModel.createClub(
                name: values.name,
                code: values.code,
                adminEmail: values.adminEmail,
                adminName: values.adminName,
              )
            : viewModel.updateClub(
                clubId: club.id,
                name: values.name,
                code: values.code,
              ),
      ),
    );
    if (saved ?? false) {
      messenger.showSnackBar(
        SnackBar(content: Text(club == null ? 'Club creado' : 'Club guardado')),
      );
    }
  }

  Future<void> _toggleActive(BuildContext context, PlatformClub club) async {
    final messenger = ScaffoldMessenger.of(context);
    final viewModel = context.read<PlatformViewModel>();
    if (club.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('¿Desactivar ${club.name}?'),
          content: const Text(
            'Sus socios dejarán de verlo en la app hasta que lo vuelvas a '
            'activar. No se borra ningún dato.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-deactivate'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return;
    }
    final error = await viewModel.setActive(club, active: !club.isActive);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ?? (club.isActive ? 'Club desactivado' : 'Club activado'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PlatformViewModel>();
    final session = context.watch<SessionViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma · Clubes'),
        actions: [
          if (session.clubs.isNotEmpty)
            IconButton(
              tooltip: 'Volver a mis clubes',
              icon: const Icon(Icons.close),
              onPressed: session.closePlatform,
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: session.signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-club'),
        onPressed: () => _showForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo club'),
      ),
      body: switch (viewModel) {
        PlatformViewModel(isLoading: true, clubs: []) => const Center(
          child: CircularProgressIndicator(),
        ),
        PlatformViewModel(:final loadError?) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loadError),
              TextButton(
                onPressed: viewModel.load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        PlatformViewModel(clubs: []) => const Center(
          child: Text('Todavía no hay clubes. Crea el primero.'),
        ),
        _ => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final club in viewModel.clubs)
              _PlatformClubTile(
                club: club,
                canEnter:
                    club.isActive && session.clubs.any((c) => c.id == club.id),
                onEdit: () => _showForm(context, club: club),
                onToggleActive: () => _toggleActive(context, club),
                onEnter: () => session.selectClub(club.id),
              ),
          ],
        ),
      },
    );
  }
}

class _PlatformClubTile extends StatelessWidget {
  const _PlatformClubTile({
    required this.club,
    required this.canEnter,
    required this.onEdit,
    required this.onToggleActive,
    required this.onEnter,
  });

  final PlatformClub club;
  final bool canEnter;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final admin = switch (club) {
      PlatformClub(:final adminEmail?) => 'Admin: $adminEmail',
      PlatformClub(:final pendingAdminEmail?) =>
        'Admin pendiente de alta: $pendingAdminEmail',
      _ => 'Sin administrador',
    };
    final members = club.memberCount == 1
        ? '1 socio'
        : '${club.memberCount} socios';
    return ListTile(
      key: Key('platform-club-${club.code}'),
      title: Row(
        children: [
          Flexible(child: Text(club.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(club.isActive ? 'Activo' : 'Desactivado'),
            backgroundColor: club.isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
      subtitle: Text('${club.code} · $members\n$admin'),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        key: Key('platform-club-menu-${club.code}'),
        onSelected: (action) => switch (action) {
          'edit' => onEdit(),
          'toggle' => onToggleActive(),
          'enter' => onEnter(),
          _ => null,
        },
        itemBuilder: (_) => [
          if (canEnter)
            const PopupMenuItem(value: 'enter', child: Text('Entrar al club')),
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(
            value: 'toggle',
            child: Text(club.isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
  }
}
