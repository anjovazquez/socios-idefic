import '../season/season_membership.dart';
import 'payment.dart';

/// «Mi suscripción» of the member in the active club (RF-011).
class MySubscription {
  const MySubscription({
    this.seasonName,
    this.seasonMembershipId,
    this.feeCents,
    this.status,
    this.lastMethod,
    this.nextChargeCents,
    this.nextChargeOn,
  });

  /// Null when the club has no active season.
  final String? seasonName;
  final String? seasonMembershipId;
  final int? feeCents;

  /// Null when there is no active season.
  final SeasonMembershipStatus? status;

  /// Method of the last paid fee, if any.
  final PaymentMethod? lastMethod;

  /// Automatic renewals (phase 6) will schedule the next charge.
  final int? nextChargeCents;
  final DateTime? nextChargeOn;

  bool get hasSeason => seasonName != null;

  bool get canPay =>
      status == SeasonMembershipStatus.pendingPayment &&
      seasonMembershipId != null;
}

/// One line of the payment history of the member (RF-016).
class MyPayment {
  const MyPayment({
    required this.id,
    required this.seasonName,
    required this.concept,
    required this.amountCents,
    required this.date,
    required this.status,
    this.method,
    this.receiptNumber,
  });

  final String id;
  final String seasonName;
  final String concept;
  final int amountCents;
  final DateTime date;
  final PaymentStatus status;
  final PaymentMethod? method;

  /// Only paid payments have a receipt (RF-017).
  final int? receiptNumber;

  bool get hasReceipt => status == PaymentStatus.paid && receiptNumber != null;
}
