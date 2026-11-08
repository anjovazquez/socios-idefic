/// Minimum states of a payment (RF-015).
enum PaymentStatus { pending, paid, failed, cancelled }

/// How the fee was paid. Manual methods are recorded by the club admin.
enum PaymentMethod { cash, transfer, bizum, card, sepa, other }

const manualPaymentMethods = [
  PaymentMethod.cash,
  PaymentMethod.transfer,
  PaymentMethod.bizum,
  PaymentMethod.other,
];

enum PaymentProvider { manual, stripe }

/// A payment of a season fee, always in euro cents (D-007).
class Payment {
  const Payment({
    required this.id,
    required this.seasonMembershipId,
    required this.amountCents,
    required this.concept,
    required this.status,
    required this.provider,
    required this.createdAt,
    this.method,
    this.reference,
    this.paidAt,
  });

  final String id;
  final String seasonMembershipId;
  final int amountCents;
  final String concept;
  final PaymentStatus status;
  final PaymentProvider provider;
  final PaymentMethod? method;
  final String? reference;
  final DateTime? paidAt;
  final DateTime createdAt;

  /// Manual payments recorded by mistake can be cancelled by the admin;
  /// pending ones too (RF-015 transitions are enforced by the server).
  bool get canBeCancelled =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.failed ||
      (status == PaymentStatus.paid && provider == PaymentProvider.manual);
}

sealed class PaymentFailure implements Exception {
  const PaymentFailure();
}

final class InvalidPaymentAmountFailure extends PaymentFailure {
  const InvalidPaymentAmountFailure();
}

final class AlreadyPaidFailure extends PaymentFailure {
  const AlreadyPaidFailure();
}

final class InvalidPaymentTransitionFailure extends PaymentFailure {
  const InvalidPaymentTransitionFailure();
}

final class NotPayableFailure extends PaymentFailure {
  const NotPayableFailure();
}

/// Only paid payments have a receipt.
final class NoReceiptFailure extends PaymentFailure {
  const NoReceiptFailure();
}

/// The platform or the club cannot take online payments yet.
final class OnlinePaymentsUnavailableFailure extends PaymentFailure {
  const OnlinePaymentsUnavailableFailure();
}

final class PaymentPermissionFailure extends PaymentFailure {
  const PaymentPermissionFailure();
}

final class PaymentUnavailableFailure extends PaymentFailure {
  const PaymentUnavailableFailure([this.cause]);

  final Object? cause;
}
