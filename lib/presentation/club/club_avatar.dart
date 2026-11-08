import 'package:flutter/material.dart';

import '../../domain/club/my_club.dart';

/// Parses a `#RRGGBB` club color.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

/// Club identity mark. Shows initials over the club color until logos
/// arrive in VS-004.
class ClubAvatar extends StatelessWidget {
  const ClubAvatar({super.key, required this.club, this.radius = 24});

  final MyClub club;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = parseHexColor(club.primaryColor) ?? scheme.primary;
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final initials = club.name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initials,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: foreground),
      ),
    );
  }
}
