/// How the current user relates to a club. [platformAdmin] means access
/// through the platform administration, without a membership (§17).
enum ClubRole { clubAdmin, member, platformAdmin }

/// A club the current user can enter, seen through their membership.
class MyClub {
  const MyClub({
    required this.id,
    required this.name,
    required this.code,
    required this.role,
    this.logoUrl,
    this.imageUrl,
    this.primaryColor,
    this.secondaryColor,
    this.memberNumber,
  });

  final String id;
  final String name;
  final String code;
  final ClubRole role;

  /// Public URLs of the club brand assets, if any.
  final String? logoUrl;
  final String? imageUrl;

  /// Hex color `#RRGGBB` chosen by the club, if any.
  final String? primaryColor;
  final String? secondaryColor;

  /// Per-club member number (RN-006).
  final int? memberNumber;

  /// Club admins and platform admins manage the club (§16).
  bool get canAdminister =>
      role == ClubRole.clubAdmin || role == ClubRole.platformAdmin;
}
