import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/perk/perk.dart';
import '../../domain/sponsor/sponsor.dart';
import '../blog/post_widgets.dart';
import '../common/open_url.dart';
import '../session/session_view_model.dart';
import '../sponsor/sponsor_widgets.dart';
import 'perk_labels.dart';

/// «Mis ventajas»: valid perks of the active club (RF-025).
class MyPerksPage extends StatefulWidget {
  const MyPerksPage({super.key});

  @override
  State<MyPerksPage> createState() => _MyPerksPageState();
}

class _MyPerksPageState extends State<MyPerksPage> {
  late Future<List<Perk>> _perks = _load();

  Future<List<Perk>> _load() => context.read<AppUseCases>().getMyPerks(
    context.read<SessionViewModel>().activeClub!.id,
  );

  @override
  Widget build(BuildContext context) {
    final clubName = context.read<SessionViewModel>().activeClub?.name ?? '';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis ventajas'),
        leading: BackButton(onPressed: () => context.go('/club')),
      ),
      body: FutureBuilder<List<Perk>>(
        future: _perks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'No hemos podido cargar tus ventajas. Inténtalo de nuevo en '
                'un momento',
              ),
            );
          }
          final perks = snapshot.data;
          if (perks == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _perks = _load());
              await _perks;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (perks.isEmpty)
                  Card(
                    key: const Key('my-perks-empty'),
                    child: ListTile(
                      leading: const Icon(Icons.local_offer_outlined),
                      title: const Text('Ahora mismo no hay ventajas'),
                      subtitle: Text(
                        'Cuando $clubName publique descuentos o ventajas para '
                        'socios, los verás aquí.',
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Enseña tu carnet de socio para disfrutarlas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final perk in perks) _PerkCard(perk: perk),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard({required this.perk});

  final Perk perk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useCases = context.read<AppUseCases>();
    return Card(
      key: Key('my-perk-${perk.title}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/club/benefits/detail', extra: perk),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (perk.imagePath != null)
              PostImage(url: useCases.getPostImageUrl(perk.imagePath!)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (perk.sponsorName != null) ...[
                    SponsorLogo(sponsor: _sponsorOf(perk), size: 48),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(perk.title, style: theme.textTheme.titleMedium),
                        if (perk.sponsorName != null)
                          Text(
                            perk.sponsorName!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          perkValidity(perk),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Sponsor _sponsorOf(Perk perk) => Sponsor(
  id: perk.sponsorId ?? perk.id,
  name: perk.sponsorName ?? '',
  logoUrl: perk.sponsorLogoUrl,
  websiteUrl: perk.sponsorWebsiteUrl,
);

/// A perk with how to use it and a shortcut to the card (RF-025).
class PerkDetailPage extends StatelessWidget {
  const PerkDetailPage({super.key, required this.perk});

  final Perk? perk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perk = this.perk;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventaja'),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/club/benefits'),
        ),
      ),
      body: perk == null
          ? const Center(child: Text('Esta ventaja ya no está disponible.'))
          : ListView(
              children: [
                if (perk.imagePath != null)
                  PostImage(
                    url: context.read<AppUseCases>().getPostImageUrl(
                      perk.imagePath!,
                    ),
                    height: 200,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perk.title,
                        key: const Key('perk-detail-title'),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        perkValidity(perk),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(perk.body, style: theme.textTheme.bodyLarge),
                      if (perk.sponsorName != null) ...[
                        const SizedBox(height: 16),
                        ListTile(
                          key: const Key('perk-detail-sponsor'),
                          contentPadding: EdgeInsets.zero,
                          leading: SponsorLogo(sponsor: _sponsorOf(perk)),
                          title: Text(perk.sponsorName!),
                          subtitle: perk.sponsorWebsiteUrl == null
                              ? null
                              : const Text('Ver su web'),
                          trailing: perk.sponsorWebsiteUrl == null
                              ? null
                              : const Icon(Icons.open_in_new),
                          onTap: perk.sponsorWebsiteUrl == null
                              ? null
                              : () => context.read<WebsiteOpener>().open(
                                  Uri.parse(perk.sponsorWebsiteUrl!),
                                ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Card(
                        color: theme.colorScheme.secondaryContainer,
                        child: ListTile(
                          leading: Icon(
                            Icons.badge_outlined,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          title: Text(
                            'Presenta tu carnet de socio para disfrutar de '
                            'esta ventaja.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('perk-show-card'),
                          onPressed: () => context.go('/club/card'),
                          icon: const Icon(Icons.badge_outlined),
                          label: const Text('Mostrar mi carnet'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
