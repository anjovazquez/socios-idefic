import '../../domain/payment/payment_gateway.dart';
import '../../domain/payment/payments_repository.dart';

/// Online payment (ADR-001): Stripe Checkout in the club's connected account.
/// The webhook, not the app, marks the payment as paid.
class StripePaymentGateway implements PaymentGateway {
  const StripePaymentGateway(this._payments);

  final PaymentsRepository _payments;

  @override
  Future<PaymentStart> start({
    required String clubId,
    required String seasonMembershipId,
  }) async =>
      RedirectPaymentStart(await _payments.createCheckout(seasonMembershipId));
}
