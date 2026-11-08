import '../../domain/club/active_club_store.dart';
import '../../domain/club/my_club.dart';

class UnknownClubFailure implements Exception {
  const UnknownClubFailure(this.clubId);

  final String clubId;
}

/// Switches the active club without signing in again (RF-030).
class SelectActiveClub {
  const SelectActiveClub(this._activeClubStore);

  final ActiveClubStore _activeClubStore;

  Future<MyClub> call(String clubId, List<MyClub> availableClubs) async {
    final club = availableClubs.where((c) => c.id == clubId).firstOrNull;
    if (club == null) throw UnknownClubFailure(clubId);
    await _activeClubStore.write(club.id);
    return club;
  }
}
