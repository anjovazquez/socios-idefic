import 'onboarding.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingStatus> getStatus();

  /// Signs in with the one-time token of an invitation email.
  Future<void> verifyInvitation({
    required String tokenHash,
    required String type,
  });

  Future<void> setPassword(String password);

  /// Saves the data, records the accepted conditions and activates the
  /// pending memberships, all at once.
  Future<void> complete({
    required PersonalData data,
    required String termsVersion,
  });
}
