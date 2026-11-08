import '../../domain/member/club_member.dart';
import '../../domain/member/members_repository.dart';

class GetClubMembers {
  const GetClubMembers(this._repository);

  final MembersRepository _repository;

  Future<List<ClubMember>> call(String clubId) =>
      _repository.getMembers(clubId);
}

class InviteMember {
  const InviteMember(this._repository);

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final MembersRepository _repository;

  Future<InvitationOutcome> call({
    required String clubId,
    required String email,
    required String firstName,
  }) {
    final name = firstName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    if (name.isEmpty) {
      throw const InvalidMemberDataFailure(MemberField.name);
    }
    if (!_email.hasMatch(normalizedEmail)) {
      throw const InvalidMemberDataFailure(MemberField.email);
    }
    return _repository.invite(
      clubId: clubId,
      email: normalizedEmail,
      firstName: name,
    );
  }
}

class ResendInvitation {
  const ResendInvitation(this._repository);

  final MembersRepository _repository;

  Future<void> call(String membershipId) =>
      _repository.resendInvitation(membershipId);
}
