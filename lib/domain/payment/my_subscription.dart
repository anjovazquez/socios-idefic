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
    this.onlinePayments = false,
    this.nextChargeSeason,
    this.nextChargeSeasonMembershipId,
    this.nextChargeCancellable = false,
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
  final String? nextChargeSeason;

  /// Renewal of the next charge, which can be cancelled before it (RF-014).
  final String? nextChargeSeasonMembershipId;
  final bool nextChargeCancellable;

  bool get hasNextCharge => nextChargeCents != null && nextChargeOn != null;

  /// The club takes online payments (Stripe account active).
  final bool onlinePayments;

  bool get hasSeason => seasonName != null;

  bool get canPay =>
      status == SeasonMembershipStatus.pendingPayment &&
      seasonMembershipId != null;

  bool get canPayOnline => canPay && onlinePayments;
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

enum SavedMethodKind { card, sepaDebit }

/// Payment method kept for automatic renewals (RF-012). Masked data only.
class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.kind,
    this.brand,
    this.last4,
    this.country,
  });

  final SavedMethodKind kind;
  final String? brand;
  final String? last4;
  final String? country;
}

/// Whether the member renews automatically and with which method.
class RenewalSetup {
  const RenewalSetup({this.method, this.autoRenew = false});

  static const none = RenewalSetup();

  final SavedPaymentMethod? method;
  final bool autoRenew;

  bool get isAutomatic => autoRenew && method != null;
}
