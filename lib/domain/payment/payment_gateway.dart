/// How the member pays their fee, independent from the provider (§9).
/// The manual gateway shows the club instructions; Stripe (VS-021) will
/// return a checkout URL.
abstract interface class PaymentGateway {
  /// [saveForRenewal]: keep the method for automatic renewals (VS-022);
  /// only providers with recurring payments use it.
  Future<PaymentStart> start({
    required String clubId,
    required String seasonMembershipId,
    bool saveForRenewal = false,
  });
}

sealed class PaymentStart {
  const PaymentStart();
}

/// Pay outside the app following the club instructions.
final class ManualPaymentStart extends PaymentStart {
  const ManualPaymentStart(this.instructions);

  final String? instructions;
}

/// Continue on the provider page.
final class RedirectPaymentStart extends PaymentStart {
  const RedirectPaymentStart(this.url);

  final Uri url;
}
