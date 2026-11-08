import 'my_club.dart';

abstract interface class ClubRepository {
  /// Active clubs where the signed-in user has an active membership.
  Future<List<MyClub>> getMyClubs();
}
