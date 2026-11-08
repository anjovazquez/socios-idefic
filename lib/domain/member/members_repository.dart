import 'club_member.dart';

abstract interface class MembersRepository {
  Future<List<ClubMember>> getMembers(String clubId);

  /// Signs up a member and sends the invitation email (RF-002).
  Future<InvitationOutcome> invite({
    required String clubId,
    required String email,
    required String firstName,
  });

  /// Only the club admin can change it; unique inside the club.
  Future<void> setMemberNumber(String membershipId, int number);

  /// Sends a new link; the previous one stops working.
  Future<void> resendInvitation(String membershipId);
}
