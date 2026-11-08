import '../../domain/payment/payment_gateway.dart';
import '../../domain/payment/payments_repository.dart';

/// First provider (D-011): the member pays outside the app (transfer,
/// Bizum, cash) following the club instructions; the admin records it.
class ManualPaymentGateway implements PaymentGateway {
  const ManualPaymentGateway(this._payments);

  final PaymentsRepository _payments;

  @override
  Future<PaymentStart> start({
    required String clubId,
    required String seasonMembershipId,
    bool saveForRenewal = false,
  }) async =>
      ManualPaymentStart(await _payments.getPaymentInstructions(clubId));
}
