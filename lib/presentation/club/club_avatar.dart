import 'package:flutter/material.dart';

import '../theme/club_theme.dart';

/// Club identity mark: the logo, or the initials over the club color.
class ClubAvatar extends StatelessWidget {
  const ClubAvatar({
    super.key,
    required this.name,
    this.logoUrl,
    this.primaryColor,
    this.radius = 24,
  });

  final String name;
  final String? logoUrl;
  final String? primaryColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final background =
        parseHexColor(primaryColor) ?? Theme.of(context).colorScheme.primary;
    final initials = Center(
      child: Text(
        name
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .take(2)
            .map((word) => word[0].toUpperCase())
            .join(),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: readableOn(background)),
      ),
    );
    return Semantics(
      label: 'Logo de $name',
      child: CircleAvatar(
        radius: radius,
        backgroundColor: logoUrl == null
            ? background
            : Theme.of(context).colorScheme.surface,
        child: logoUrl == null
            ? initials
            : ClipOval(
                child: Image.network(
                  logoUrl!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => initials,
                ),
              ),
      ),
    );
  }
}
