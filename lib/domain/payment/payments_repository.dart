import 'my_subscription.dart';
import 'payment.dart';

abstract interface class PaymentsRepository {
  /// Payments of one member in one season, newest first.
  Future<List<Payment>> getSeasonPayments(String seasonMembershipId);

  /// Records a fee paid outside the app; null [amountCents] = the fee.
  Future<void> recordManualPayment({
    required String seasonMembershipId,
    required PaymentMethod method,
    int? amountCents,
    DateTime? paidOn,
    String? reference,
  });

  /// Only `failed` or `cancelled`; the server checks the transition.
  Future<void> setStatus(String paymentId, PaymentStatus status);

  Future<String?> getPaymentInstructions(String clubId);

  Future<void> setPaymentInstructions(String clubId, String instructions);

  /// Subscription of the signed-in member in [clubId].
  Future<MySubscription> getMySubscription(String clubId);

  /// Payments of the signed-in member in [clubId], newest first.
  Future<List<MyPayment>> getMyPayments(String clubId);
}
