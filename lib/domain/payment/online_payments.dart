/// Online payments of a club through its Stripe connected account (ADR-001).
enum OnlinePaymentsStatus {
  /// The club has not started the Stripe onboarding.
  notConnected,

  /// Account created; Stripe still has to verify it (KYC).
  pendingVerification,

  /// Members can pay online.
  active,
}

OnlinePaymentsStatus onlinePaymentsStatusOf({
  required String? accountId,
  required bool chargesEnabled,
}) => accountId == null
    ? OnlinePaymentsStatus.notConnected
    : chargesEnabled
    ? OnlinePaymentsStatus.active
    : OnlinePaymentsStatus.pendingVerification;
