import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../blog/home_feed_view_model.dart';
import '../blog/post_widgets.dart';
import '../dashboard/club_dashboard_section.dart';
import '../session/session_view_model.dart';
import '../sponsor/club_sponsors_section.dart';
import 'club_avatar.dart';

/// «Inicio» (§14): club identity, the card shortcut, the admin summary,
/// news and sponsors. The other sections live in the bottom bar (ClubShell).
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
          if (club.canAdminister) const _AdminMenu(),
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
      body: ChangeNotifierProvider(
        key: ValueKey(club.id),
        create: (context) =>
            HomeFeedViewModel(context.read<AppUseCases>(), clubId: club.id)
              ..load(),
        child: Consumer<HomeFeedViewModel>(
          builder: (context, feed, _) => RefreshIndicator(
            onRefresh: feed.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      children: [
                        ClubAvatar(
                          name: club.name,
                          logoUrl: club.logoUrl,
                          primaryColor: club.primaryColor,
                          radius: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(club.name, style: theme.textTheme.headlineSmall),
                        if (club.activeSeasonName case final season?) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Temporada $season',
                            key: const Key('home-season'),
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                        if (club.memberNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Socio nº ${club.memberNumber}',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                        const SizedBox(height: 24),
                        // The card is what members use most (at the door).
                        FilledButton.icon(
                          key: const Key('home-show-card'),
                          onPressed: () => context.go('/club/card'),
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Mostrar mi carnet'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (club.canAdminister) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ClubDashboardSection(
                        key: ValueKey('dashboard-${club.id}'),
                        clubId: club.id,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _HomeNews(feed: feed, clubName: club.name),
                const SizedBox(height: 32),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ClubSponsorsSection(
                      key: ValueKey('sponsors-${club.id}'),
                      clubId: club.id,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// News of the club in the member's home (RF-023).
class _HomeNews extends StatelessWidget {
  const _HomeNews({required this.feed, required this.clubName});

  final HomeFeedViewModel feed;
  final String clubName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Noticias', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!feed.loaded)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (feed.loadError != null)
              Text(feed.loadError!)
            else if (feed.posts.isEmpty)
              Card(
                key: const Key('feed-empty'),
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: const Text('Todavía no hay noticias'),
                  subtitle: Text('Aquí verás las novedades de $clubName.'),
                ),
              )
            else ...[
              for (final post in feed.posts)
                PostCard(
                  post: post,
                  imageUrl: feed.imageUrl(post),
                  onOpen: () => context.push(
                    Uri(
                      path: '/club/post',
                      queryParameters: {'id': post.id},
                    ).toString(),
                  ),
                ),
              if (feed.hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    key: const Key('feed-more'),
                    onPressed: feed.isLoading ? null : feed.loadMore,
                    child: const Text('Ver más noticias'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Club management for the admin in one place (§16).
class _AdminMenu extends StatelessWidget {
  const _AdminMenu();

  static const _entries = [
    ('open-members', 'Socios', Icons.people_outline, '/club/members'),
    ('open-payments', 'Pagos', Icons.payments_outlined, '/club/payments'),
    ('open-seasons', 'Temporadas', Icons.event_note_outlined, '/club/seasons'),
    ('open-news-admin', 'Noticias', Icons.campaign_outlined, '/club/news'),
    (
      'open-sponsors',
      'Patrocinadores',
      Icons.handshake_outlined,
      '/club/sponsors',
    ),
    ('open-perks-admin', 'Ventajas', Icons.local_offer_outlined, '/club/perks'),
    (
      'open-settings',
      'Configuración del club',
      Icons.settings_outlined,
      '/club/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const Key('open-admin-menu'),
    tooltip: 'Gestión del club',
    icon: const Icon(Icons.business_center_outlined),
    onSelected: (path) => context.go(path),
    itemBuilder: (context) => [
      for (final (key, label, icon, path) in _entries)
        PopupMenuItem(
          key: Key(key),
          value: path,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(label),
          ),
        ),
    ],
  );
}
