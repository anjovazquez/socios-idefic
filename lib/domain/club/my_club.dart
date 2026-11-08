enum ClubRole { clubAdmin, member }

/// A club the current user can enter, seen through their membership.
class MyClub {
  const MyClub({
    required this.id,
    required this.name,
    required this.code,
    required this.role,
    this.logoPath,
    this.primaryColor,
    this.secondaryColor,
    this.memberNumber,
  });

  final String id;
  final String name;
  final String code;
  final ClubRole role;
  final String? logoPath;

  /// Hex color `#RRGGBB` chosen by the club, if any.
  final String? primaryColor;
  final String? secondaryColor;

  /// Per-club member number (RN-006).
  final int? memberNumber;
}
