import 'renewal.dart';
import 'season.dart';
import 'season_membership.dart';

abstract interface class SeasonRepository {
  /// Newest first.
  Future<List<Season>> getSeasons(String clubId);

  Future<void> createSeason({
    required String clubId,
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  });

  /// History of a club membership, newest first.
  Future<List<MemberSeason>> getMemberSeasons(String membershipId);

  /// Custom fee (≥ 0) of a member in a season; 0 makes them active.
  Future<void> setMemberFee({
    required String seasonMembershipId,
    required int feeCents,
  });

  /// Provisional until online payments (VS-017): paid ↔ pending.
  Future<void> setSeasonMembershipStatus({
    required String seasonMembershipId,
    required SeasonMembershipStatus status,
  });

  /// Members of the previous season that can join [seasonId].
  Future<List<RenewalCandidate>> getRenewalCandidates(
    String seasonId, {
    required bool keepCustomFees,
  });

  /// Renews [items] at once; returns how many were new (idempotent).
  Future<int> bulkRenew(String seasonId, List<RenewalItem> items);

  /// Makes [seasonId] the only active season of its club with the fee.
  Future<void> activateSeason({
    required String seasonId,
    required int defaultFeeCents,
  });
}
