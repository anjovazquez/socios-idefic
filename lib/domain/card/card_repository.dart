import 'membership_card.dart';

abstract interface class CardRepository {
  /// Card of the signed-in member in [clubId], computed by the server.
  Future<MembershipCard> getMyCard(String clubId);
}
