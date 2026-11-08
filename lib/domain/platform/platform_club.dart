/// A club as seen from the platform administration.
class PlatformClub {
  const PlatformClub({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    required this.memberCount,
    this.adminEmail,
    this.pendingAdminEmail,
  });

  final String id;
  final String name;
  final String code;
  final bool isActive;
  final int memberCount;

  /// Email of the club administrator, once they have an account.
  final String? adminEmail;

  /// Administrator invited but without an account yet (VS-006 sends it).
  final String? pendingAdminEmail;
}
