import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/dashboard/club_dashboard.dart';
import '../format/money.dart';

/// «Resumen del club» for the admin (§16 Dashboard): stat tiles (number +
/// label + icon, no charts) and shortcuts to frequent tasks.
class ClubDashboardSection extends StatefulWidget {
  const ClubDashboardSection({super.key, required this.clubId});

  final String clubId;

  @override
  State<ClubDashboardSection> createState() => _ClubDashboardSectionState();
}

class _ClubDashboardSectionState extends State<ClubDashboardSection> {
  late final Future<ClubDashboard> _dashboard = context
      .read<AppUseCases>()
      .getClubDashboard(widget.clubId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('admin-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Resumen del club', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        FutureBuilder<ClubDashboard>(
          future: _dashboard,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'No hemos podido cargar el resumen. Inténtalo de nuevo en un '
                'momento',
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _Summary(data: data);
          },
        ),
        const SizedBox(height: 12),
        const _Shortcuts(),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final ClubDashboard data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.seasonName == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.event_busy),
          title: const Text('No hay temporada activa'),
          subtitle: const Text(
            'Activa una temporada para empezar a cobrar cuotas.',
          ),
          trailing: TextButton(
            onPressed: () => context.go('/club/seasons'),
            child: const Text('Temporadas'),
          ),
        ),
      );
    }
    final tiles = [
      _Stat(
        key: const Key('stat-active'),
        icon: Icons.verified_outlined,
        value: '${data.activeMembers}',
        label: 'Socios activos',
      ),
      _Stat(
        key: const Key('stat-pending'),
        icon: Icons.schedule,
        value: '${data.pendingMembers}',
        label: 'Pendientes de pago',
      ),
      _Stat(
        key: const Key('stat-paid'),
        icon: Icons.payments_outlined,
        value: formatCents(data.paidCents),
        label: 'Cobrado',
      ),
      _Stat(
        key: const Key('stat-pending-amount'),
        icon: Icons.hourglass_bottom,
        value: formatCents(data.pendingCents),
        label: 'Pendiente de cobro',
      ),
      _Stat(
        key: const Key('stat-not-renewed'),
        icon: Icons.person_off_outlined,
        value: '${data.notRenewedMembers}',
        label: 'Sin renovar',
      ),
      _Stat(
        key: const Key('stat-invited'),
        icon: Icons.mail_outline,
        value: '${data.invitedMembers}',
        label: 'Invitaciones sin activar',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Temporada ${data.seasonName}',
          key: const Key('dashboard-season'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 3 : 2;
            final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tile in tiles) SizedBox(width: width, child: tile),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '${data.autoRenewMembers} con renovación automática · '
          '${data.validPerks} ventajas vigentes · '
          '${data.seasonSponsors} patrocinadores esta temporada',
          key: const Key('dashboard-extra'),
          style: theme.textTheme.bodySmall,
        ),
        if (data.latestPosts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Últimas noticias', style: theme.textTheme.titleSmall),
          for (final post in data.latestPosts)
            Text(
              '${formatDate(post.publishedAt.toLocal())} · ${post.title}',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ],
    );
  }
}

/// A headline number with its label (stat tile, DESIGN.md §6).
class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineSmall),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ActionChip(
        key: const Key('shortcut-new-member'),
        avatar: const Icon(Icons.person_add_alt_1, size: 18),
        label: const Text('Nuevo socio'),
        onPressed: () => context.go('/club/members?nuevo=1'),
      ),
      ActionChip(
        key: const Key('shortcut-record-payment'),
        avatar: const Icon(Icons.payments_outlined, size: 18),
        label: const Text('Registrar pago'),
        onPressed: () => context.go('/club/payments?estado=pendientes'),
      ),
      ActionChip(
        key: const Key('shortcut-new-post'),
        avatar: const Icon(Icons.campaign_outlined, size: 18),
        label: const Text('Nueva noticia'),
        onPressed: () => context.go('/club/news/edit'),
      ),
      ActionChip(
        key: const Key('open-perks-admin'),
        avatar: const Icon(Icons.local_offer_outlined, size: 18),
        label: const Text('Ventajas'),
        onPressed: () => context.go('/club/perks'),
      ),
    ],
  );
}
