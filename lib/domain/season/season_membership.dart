import 'season.dart';

/// Condition of a member in one season (RN-007).
enum SeasonMembershipStatus { pendingPayment, active, notRenewed, cancelled }

SeasonMembershipStatus seasonMembershipStatusFromName(String? name) =>
    switch (name) {
      'active' => SeasonMembershipStatus.active,
      'not_renewed' => SeasonMembershipStatus.notRenewed,
      'cancelled' => SeasonMembershipStatus.cancelled,
      _ => SeasonMembershipStatus.pendingPayment,
    };

/// One line of the history of a member (§7 SOCIO + CLUB + TEMPORADA).
class MemberSeason {
  const MemberSeason({
    required this.seasonName,
    required this.seasonStatus,
    required this.status,
    this.seasonMembershipId,
    this.feeCents,
  });

  /// Null when the member was not renewed for that season.
  final String? seasonMembershipId;
  final String seasonName;
  final SeasonStatus seasonStatus;
  final SeasonMembershipStatus status;
  final int? feeCents;
}
