enum MemberStatus { invited, active, inactive }

/// A person in a club, as seen by its administration.
class ClubMember {
  const ClubMember({
    required this.membershipId,
    required this.email,
    required this.status,
    required this.isClubAdmin,
    this.firstName,
    this.lastName,
    this.memberNumber,
    this.invitedAt,
  });

  final String membershipId;
  final String email;
  final MemberStatus status;
  final bool isClubAdmin;
  final String? firstName;
  final String? lastName;
  final int? memberNumber;

  /// Last time an invitation email was sent.
  final DateTime? invitedAt;

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? email : name;
  }
}

enum InvitationOutcome {
  /// A new account was created and the activation email sent.
  invited,

  /// The email already had an account: it joined the club directly (RF-004).
  addedExistingAccount,
}

enum MemberField { name, email, memberNumber }

sealed class MemberFailure implements Exception {
  const MemberFailure();
}

final class InvalidMemberDataFailure extends MemberFailure {
  const InvalidMemberDataFailure(this.field);

  final MemberField field;
}

final class AlreadyMemberFailure extends MemberFailure {
  const AlreadyMemberFailure();
}

/// Another member of the club already has that number (RF-006).
final class MemberNumberTakenFailure extends MemberFailure {
  const MemberNumberTakenFailure();
}

final class InvitationNotPendingFailure extends MemberFailure {
  const InvitationNotPendingFailure();
}

final class MemberPermissionFailure extends MemberFailure {
  const MemberPermissionFailure();
}

final class MemberUnavailableFailure extends MemberFailure {
  const MemberUnavailableFailure([this.cause]);

  final Object? cause;
}
