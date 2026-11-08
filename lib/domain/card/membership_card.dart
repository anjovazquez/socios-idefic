/// State of the card for the active season (RF-021, RN-014).
enum CardState { active, pendingPayment, notRenewed, noSeason }

/// Digital membership card of the signed-in member (RF-019).
class MembershipCard {
  const MembershipCard({
    required this.clubName,
    required this.state,
    this.clubLogoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.firstName,
    this.lastName,
    this.photoUrl,
    this.memberNumber,
    this.seasonName,
    this.cardToken,
  });

  final String clubName;
  final CardState state;
  final String? clubLogoUrl;
  final String? primaryColor;
  final String? secondaryColor;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final int? memberNumber;
  final String? seasonName;

  /// Opaque token of the QR; only present on an active card (VS-016).
  final String? cardToken;

  bool get isActive => state == CardState.active;

  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
}

sealed class CardFailure implements Exception {
  const CardFailure();
}

final class NotAMemberFailure extends CardFailure {
  const NotAMemberFailure();
}

final class CardUnavailableFailure extends CardFailure {
  const CardUnavailableFailure([this.cause]);

  final Object? cause;
}
