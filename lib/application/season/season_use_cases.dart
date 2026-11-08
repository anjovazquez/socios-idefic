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

class SetSeasonMembershipPaid {
  const SetSeasonMembershipPaid(this._repository);

  final SeasonRepository _repository;

  Future<void> call({required String seasonMembershipId, required bool paid}) =>
      _repository.setSeasonMembershipStatus(
        seasonMembershipId: seasonMembershipId,
        status: paid
            ? SeasonMembershipStatus.active
            : SeasonMembershipStatus.pendingPayment,
      );
}
