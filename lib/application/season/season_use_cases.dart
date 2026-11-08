import '../../domain/season/renewal.dart';
import '../../domain/season/season.dart';
import '../../domain/season/season_membership.dart';
import '../../domain/season/season_repository.dart';

class GetSeasons {
  const GetSeasons(this._repository);

  final SeasonRepository _repository;

  Future<List<Season>> call(String clubId) => _repository.getSeasons(clubId);
}

class CreateSeason {
  const CreateSeason(this._repository);

  final SeasonRepository _repository;

  Future<void> call({
    required String clubId,
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  }) {
    if (!isValidSeasonName(name)) {
      throw const InvalidSeasonDataFailure(SeasonField.name);
    }
    if (startsOn != null && endsOn != null && !endsOn.isAfter(startsOn)) {
      throw const InvalidSeasonDataFailure(SeasonField.dates);
    }
    return _repository.createSeason(
      clubId: clubId,
      name: name.trim(),
      startsOn: startsOn,
      endsOn: endsOn,
    );
  }
}

class ActivateSeason {
  const ActivateSeason(this._repository);

  final SeasonRepository _repository;

  /// [fee] as typed in euros.
  Future<void> call({required Season season, required String fee}) {
    if (season.status == SeasonStatus.closed) {
      throw const SeasonClosedFailure();
    }
    final cents = parseEurosToCents(fee);
    if (cents == null) throw const InvalidSeasonDataFailure(SeasonField.fee);
    return _repository.activateSeason(
      seasonId: season.id,
      defaultFeeCents: cents,
    );
  }
}

class GetMemberSeasons {
  const GetMemberSeasons(this._repository);

  final SeasonRepository _repository;

  Future<List<MemberSeason>> call(String membershipId) =>
      _repository.getMemberSeasons(membershipId);
}

class SetMemberFee {
  const SetMemberFee(this._repository);

  final SeasonRepository _repository;

  /// [fee] as typed in euros; 0 for exempt or honorary members.
  Future<void> call({required String seasonMembershipId, required String fee}) {
    final cents = parseEurosToCents(fee);
    if (cents == null) throw const InvalidSeasonDataFailure(SeasonField.fee);
    return _repository.setMemberFee(
      seasonMembershipId: seasonMembershipId,
      feeCents: cents,
    );
  }
}

class GetRenewalCandidates {
  const GetRenewalCandidates(this._repository);

  final SeasonRepository _repository;

  Future<List<RenewalCandidate>> call(
    String seasonId, {
    bool keepCustomFees = true,
  }) => _repository.getRenewalCandidates(
    seasonId,
    keepCustomFees: keepCustomFees,
  );
}

class BulkRenew {
  const BulkRenew(this._repository);

  final SeasonRepository _repository;

  Future<int> call(String seasonId, List<RenewalItem> items) {
    if (items.isEmpty) throw const NothingToRenewFailure();
    if (items.any((item) => item.feeCents < 0)) {
      throw const InvalidSeasonDataFailure(SeasonField.fee);
    }
    return _repository.bulkRenew(seasonId, items);
  }
}
