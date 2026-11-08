import 'package:flutter/material.dart';

import '../../domain/sponsor/sponsor.dart';

/// Sponsor logo on a white tile (logos are designed for light backgrounds);
/// initials when there is none or it cannot be loaded.
class SponsorLogo extends StatelessWidget {
  const SponsorLogo({super.key, required this.sponsor, this.size = 56});

  final Sponsor sponsor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = sponsor.name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final fallback = Center(
      child: Text(
        initials,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
    return Semantics(
      label: 'Logo de ${sponsor.name}',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: sponsor.logoUrl == null
            ? fallback
            : Image.network(
                sponsor.logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => fallback,
              ),
      ),
    );
  }
}
