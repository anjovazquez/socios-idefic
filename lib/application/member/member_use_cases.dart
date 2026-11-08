import '../../domain/member/club_member.dart';
import '../../domain/member/members_repository.dart';

class GetClubMembers {
  const GetClubMembers(this._repository);

  static const pageSize = 50;

  final MembersRepository _repository;

  Future<MemberPage> call(
    String clubId, {
    String? query,
    MemberStatus? status,
    int offset = 0,
  }) {
    final trimmed = query?.trim();
    return _repository.getMembers(
      clubId,
      query: trimmed == null || trimmed.isEmpty ? null : trimmed,
      status: status,
      offset: offset,
      limit: pageSize,
    );
  }
}

class DeactivateMember {
  const DeactivateMember(this._repository);

  final MembersRepository _repository;

  Future<void> call(ClubMember member) {
    if (member.isClubAdmin) throw const CannotDeactivateAdminFailure();
    return _repository.deactivate(member.membershipId);
  }
}

class ReactivateMember {
  const ReactivateMember(this._repository);

  final MembersRepository _repository;

  Future<MemberStatus> call(ClubMember member) =>
      _repository.reactivate(member.membershipId);
}

class GetMemberPhotoUrl {
  const GetMemberPhotoUrl(this._repository);

  final MembersRepository _repository;

  Future<String?> call(ClubMember member) async {
    final path = member.photoPath;
    if (path == null) return null;
    try {
      return await _repository.memberPhotoUrl(path);
    } catch (_) {
      return null;
    }
  }
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

class SetMemberNumber {
  const SetMemberNumber(this._repository);

  final MembersRepository _repository;

  /// [number] as typed by the admin.
  Future<void> call({required String membershipId, required String number}) {
    final parsed = int.tryParse(number.trim());
    if (parsed == null || parsed <= 0) {
      throw const InvalidMemberDataFailure(MemberField.memberNumber);
    }
    return _repository.setMemberNumber(membershipId, parsed);
  }
}
