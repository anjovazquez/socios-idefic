import 'package:flutter/material.dart';

import '../../domain/card/membership_card.dart';
import '../club/club_avatar.dart';
import '../theme/club_theme.dart';

/// The card itself (DESIGN.md §6): club colors, logo, photo, name, member
/// number, season and the QR area. Credit-card proportions; readable in the
/// sun (high contrast text with [readableOn]).
class MembershipCardView extends StatelessWidget {
  const MembershipCardView({super.key, required this.card, this.qr});

  final MembershipCard card;

  /// QR of the card (VS-016); a placeholder until then.
  final Widget? qr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary =
        parseHexColor(card.primaryColor) ?? BrandTokens.defaultPrimary;
    final secondary = parseHexColor(card.secondaryColor);
    final onPrimary = readableOn(primary);
    final textTheme = theme.textTheme.apply(
      bodyColor: onPrimary,
      displayColor: onPrimary,
    );
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        key: const Key('membership-card'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, Color.lerp(primary, BrandTokens.dark, 0.3)!],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClubAvatar(
                  name: card.clubName,
                  logoUrl: card.clubLogoUrl,
                  primaryColor: card.primaryColor,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card.clubName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('CARNET DE SOCIO', style: textTheme.labelSmall),
              ],
            ),
            if (secondary != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  key: const Key('card-accent'),
                  height: 4,
                  width: 56,
                  decoration: BoxDecoration(
                    color: secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Semantics(
                  label: 'Foto de ${card.fullName}',
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: onPrimary.withValues(alpha: 0.2),
                    backgroundImage: card.photoUrl == null
                        ? null
                        : NetworkImage(card.photoUrl!),
                    onBackgroundImageError: card.photoUrl == null
                        ? null
                        : (_, _) {},
                    child: card.photoUrl == null
                        ? Icon(Icons.person, size: 36, color: onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.fullName,
                        key: const Key('card-name'),
                        style: textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Socio nº ${card.memberNumber ?? '–'}',
                        key: const Key('card-number'),
                        style: textTheme.titleMedium,
                      ),
                      if (card.seasonName case final season?)
                        Text(
                          'Temporada $season',
                          key: const Key('card-season'),
                          style: textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 76,
                  height: 76,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: BrandTokens.light,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      qr ??
                      const Icon(
                        Icons.qr_code_2,
                        size: 64,
                        color: BrandTokens.dark,
                        semanticLabel: 'Código QR del carnet',
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
