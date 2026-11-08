/// A member of the previous season who can be renewed (RF-009).
class RenewalCandidate {
  const RenewalCandidate({
    required this.membershipId,
    required this.email,
    required this.previousSeasonName,
    required this.previousFeeCents,
    required this.previousWasCustom,
    required this.proposedFeeCents,
    required this.alreadyRenewed,
    this.firstName,
    this.lastName,
    this.memberNumber,
  });

  final String membershipId;
  final String email;
  final String? firstName;
  final String? lastName;
  final int? memberNumber;
  final String previousSeasonName;
  final int previousFeeCents;

  /// The previous fee differed from that season's ordinary fee.
  final bool previousWasCustom;
  final int proposedFeeCents;
  final bool alreadyRenewed;

  String get displayName {
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? email : name;
  }
}

/// What to renew: a member and the fee for the new season.
class RenewalItem {
  const RenewalItem({required this.membershipId, required this.feeCents});

  final String membershipId;
  final int feeCents;
}
