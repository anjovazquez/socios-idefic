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
    this.phone,
    this.birthDate,
    this.photoPath,
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

  /// Contact data for the club administration (never on the QR, RF-020).
  final String? phone;
  final DateTime? birthDate;

  /// Private photo path; shown with a short-lived URL.
  final String? photoPath;

  ClubMember copyWith({MemberStatus? status, int? memberNumber}) => ClubMember(
    membershipId: membershipId,
    email: email,
    status: status ?? this.status,
    isClubAdmin: isClubAdmin,
    firstName: firstName,
    lastName: lastName,
    memberNumber: memberNumber ?? this.memberNumber,
    invitedAt: invitedAt,
    phone: phone,
    birthDate: birthDate,
    photoPath: photoPath,
  );

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? email : name;
  }
}

/// One page of a member search.
class MemberPage {
  const MemberPage({required this.members, required this.total});

  final List<ClubMember> members;

  /// Members matching the search, across all pages.
  final int total;
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

/// The club needs its administrator (§3.2).
final class CannotDeactivateAdminFailure extends MemberFailure {
  const CannotDeactivateAdminFailure();
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
