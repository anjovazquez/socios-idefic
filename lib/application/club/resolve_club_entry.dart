import '../../domain/club/active_club_store.dart';
import '../../domain/club/club_repository.dart';
import '../../domain/club/my_club.dart';

sealed class ClubEntry {
  const ClubEntry(this.clubs);

  final List<MyClub> clubs;
}

/// The user has no active club to enter.
final class NoClubEntry extends ClubEntry {
  const NoClubEntry() : super(const []);
}

/// The user must pick one of several clubs.
final class ChooseClubEntry extends ClubEntry {
  const ChooseClubEntry(super.clubs);
}

/// The user goes straight into [club].
final class EnterClubEntry extends ClubEntry {
  const EnterClubEntry(this.club, super.clubs);

  final MyClub club;
}

/// Decides where a signed-in user lands (RF-030): straight into their only
/// club, back into the club remembered on this device, or the selector.
class ResolveClubEntry {
  const ResolveClubEntry(this._clubs, this._activeClubStore);

  final ClubRepository _clubs;
  final ActiveClubStore _activeClubStore;

  Future<ClubEntry> call() async {
    final clubs = await _clubs.getMyClubs();
    if (clubs.isEmpty) {
      await _activeClubStore.clear();
      return const NoClubEntry();
    }
    if (clubs.length == 1) {
      await _activeClubStore.write(clubs.single.id);
      return EnterClubEntry(clubs.single, clubs);
    }
    final rememberedId = await _activeClubStore.read();
    for (final club in clubs) {
      if (club.id == rememberedId) return EnterClubEntry(club, clubs);
    }
    return ChooseClubEntry(clubs);
  }
}
