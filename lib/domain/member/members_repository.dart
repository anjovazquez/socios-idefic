import 'club_member.dart';

abstract interface class MembersRepository {
  /// Search by name, email or member number, optionally by [status].
  Future<MemberPage> getMembers(
    String clubId, {
    String? query,
    MemberStatus? status,
    int offset = 0,
    int limit = 50,
  });

  /// Leaves the club keeping number and history.
  Future<void> deactivate(String membershipId);

  /// Back with the same number; returns the resulting status.
  Future<MemberStatus> reactivate(String membershipId);

  Future<String> memberPhotoUrl(String path);

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
