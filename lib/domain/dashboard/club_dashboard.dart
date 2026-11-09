/// Summary of the club for its admin (§16 Dashboard).
class ClubDashboard {
  const ClubDashboard({
    this.seasonName,
    this.activeMembers = 0,
    this.pendingMembers = 0,
    this.notRenewedMembers = 0,
    this.invitedMembers = 0,
    this.autoRenewMembers = 0,
    this.paidCents = 0,
    this.pendingCents = 0,
    this.validPerks = 0,
    this.seasonSponsors = 0,
    this.latestPosts = const [],
  });

  /// Null when the club has no active season.
  final String? seasonName;
  final int activeMembers;
  final int pendingMembers;
  final int notRenewedMembers;
  final int invitedMembers;
  final int autoRenewMembers;
  final int paidCents;
  final int pendingCents;
  final int validPerks;
  final int seasonSponsors;
  final List<DashboardPost> latestPosts;
}

class DashboardPost {
  const DashboardPost({
    required this.id,
    required this.title,
    required this.publishedAt,
  });

  final String id;
  final String title;
  final DateTime publishedAt;
}

abstract interface class DashboardRepository {
  Future<ClubDashboard> getClubDashboard(String clubId);
}
