import 'card_validation.dart';
import 'membership_card.dart';

abstract interface class CardRepository {
  /// Card of the signed-in member in [clubId], computed by the server.
  Future<MembershipCard> getMyCard(String clubId);

  /// Public check of a scanned QR; works without a session.
  Future<CardValidation> validate(String token);

  /// Issues a new token; the old QR stops working (admin only).
  Future<void> regenerate(String seasonMembershipId);
}
