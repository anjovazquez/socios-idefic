import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/app_use_cases.dart';
import '../../domain/sponsor/sponsor.dart';
import '../common/open_url.dart';
import 'sponsor_widgets.dart';

/// Active sponsors of the active season in the member's home (RF-029).
/// Nothing is shown when there are none.
class ClubSponsorsSection extends StatefulWidget {
  const ClubSponsorsSection({super.key, required this.clubId});

  final String clubId;

  @override
  State<ClubSponsorsSection> createState() => _ClubSponsorsSectionState();
}

class _ClubSponsorsSectionState extends State<ClubSponsorsSection> {
  late final Future<List<Sponsor>> _sponsors = context
      .read<AppUseCases>()
      .getActiveSponsors(widget.clubId)
      .catchError((_) => <Sponsor>[]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<Sponsor>>(
      future: _sponsors,
      builder: (context, snapshot) {
        final sponsors = snapshot.data ?? const <Sponsor>[];
        if (sponsors.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const Key('home-sponsors'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Patrocinadores', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Gracias a quienes apoyan al club esta temporada.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sponsor in sponsors) _SponsorTile(sponsor: sponsor),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SponsorTile extends StatelessWidget {
  const _SponsorTile({required this.sponsor});

  final Sponsor sponsor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final website = sponsor.websiteUrl == null
        ? null
        : Uri.tryParse(sponsor.websiteUrl!);
    return SizedBox(
      width: 140,
      child: Card(
        key: Key('home-sponsor-${sponsor.name}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: website == null
              ? null
              : () => context.read<WebsiteOpener>().open(website),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SponsorLogo(sponsor: sponsor, size: 72),
                const SizedBox(height: 8),
                Text(
                  sponsor.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                if (website != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          website.host.replaceFirst('www.', ''),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
