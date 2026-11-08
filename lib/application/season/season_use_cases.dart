import '../../domain/season/season.dart';
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
