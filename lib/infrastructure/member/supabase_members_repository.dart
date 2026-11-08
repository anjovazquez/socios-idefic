import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/member/club_member.dart';
import '../../domain/member/members_repository.dart';

class SupabaseMembersRepository implements MembersRepository {
  const SupabaseMembersRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ClubMember>> getMembers(String clubId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_club_members',
        params: {'p_club_id': clubId},
      );
      return rows.cast<Map<String, dynamic>>().map(clubMemberFromRow).toList();
    } on PostgrestException catch (error) {
      throw error.code == '42501'
          ? const MemberPermissionFailure()
          : MemberUnavailableFailure(error);
    } catch (error) {
      throw MemberUnavailableFailure(error);
    }
  }

  @override
  Future<InvitationOutcome> invite({
    required String clubId,
    required String email,
    required String firstName,
  }) async {
    final data = await _invoke({
      'action': 'invite',
      'clubId': clubId,
      'email': email,
      'firstName': firstName,
    });
    return data['status'] == 'added'
        ? InvitationOutcome.addedExistingAccount
        : InvitationOutcome.invited;
  }

  @override
  Future<void> resendInvitation(String membershipId) =>
      _invoke({'action': 'resend', 'membershipId': membershipId});

  Future<Map<String, dynamic>> _invoke(Map<String, Object?> body) async {
    try {
      final response = await _client.functions.invoke(
        'invite-member',
        body: body,
      );
      return (response.data as Map).cast<String, dynamic>();
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] as String? : null;
      throw mapInvitationError(error.status, code);
    } catch (error) {
      throw MemberUnavailableFailure(error);
    }
  }
}

ClubMember clubMemberFromRow(Map<String, dynamic> row) => ClubMember(
  membershipId: row['membership_id'] as String,
  email: row['email'] as String,
  status: switch (row['status']) {
    'invited' => MemberStatus.invited,
    'inactive' => MemberStatus.inactive,
    _ => MemberStatus.active,
  },
  isClubAdmin: row['role'] == 'club_admin',
  firstName: row['first_name'] as String?,
  lastName: row['last_name'] as String?,
  memberNumber: row['member_number'] as int?,
  invitedAt: switch (row['invited_at']) {
    final String value => DateTime.parse(value),
    _ => null,
  },
);

MemberFailure mapInvitationError(int status, String? code) => switch (code) {
  'invalid_email' => const InvalidMemberDataFailure(MemberField.email),
  'invalid_name' => const InvalidMemberDataFailure(MemberField.name),
  'already_member' => const AlreadyMemberFailure(),
  'not_pending' => const InvitationNotPendingFailure(),
  'forbidden' => const MemberPermissionFailure(),
  _ when status == 401 || status == 403 => const MemberPermissionFailure(),
  _ => MemberUnavailableFailure('$status $code'),
};
