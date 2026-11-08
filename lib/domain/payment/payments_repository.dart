import 'club_payments.dart';
import 'my_subscription.dart';
import 'online_payments.dart';
import 'payment.dart';
import 'receipt.dart';

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

  /// Receipt of a paid payment (owner or club admin).
  Future<Receipt> getReceipt(String paymentId);

  /// Payments and pending fees of the club for its admin.
  Future<ClubPaymentsPage> getClubPayments(
    String clubId, {
    ClubPaymentsFilter filter = const ClubPaymentsFilter(),
    int offset = 0,
    int limit = 50,
  });

  /// Admin: status of the club Stripe account.
  Future<OnlinePaymentsStatus> getOnlinePaymentsStatus(String clubId);

  /// Admin: creates the club account if needed; returns the onboarding page.
  Future<Uri> startOnlinePaymentsOnboarding(String clubId);

  /// Admin: reads the account status from Stripe after the onboarding.
  Future<OnlinePaymentsStatus> refreshOnlinePaymentsStatus(String clubId);

  /// Member: opens the provider checkout of a pending fee.
  Future<Uri> createCheckout(String seasonMembershipId);
}
