import 'season.dart';

abstract interface class SeasonRepository {
  /// Newest first.
  Future<List<Season>> getSeasons(String clubId);

  Future<void> createSeason({
    required String clubId,
    required String name,
    DateTime? startsOn,
    DateTime? endsOn,
  });

  /// Makes [seasonId] the only active season of its club with the fee.
  Future<void> activateSeason({
    required String seasonId,
    required int defaultFeeCents,
  });
}
