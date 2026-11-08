import '../../domain/onboarding/onboarding.dart';
import '../../domain/onboarding/onboarding_repository.dart';

class GetOnboardingStatus {
  const GetOnboardingStatus(this._repository);

  final OnboardingRepository _repository;

  Future<OnboardingStatus> call() => _repository.getStatus();
}

class VerifyInvitationLink {
  const VerifyInvitationLink(this._repository);

  static const _types = {'invite', 'magiclink'};

  final OnboardingRepository _repository;

  Future<void> call({required String? tokenHash, required String? type}) {
    if (tokenHash == null || tokenHash.isEmpty || !_types.contains(type)) {
      throw const InvitationLinkExpiredFailure();
    }
    return _repository.verifyInvitation(tokenHash: tokenHash, type: type!);
  }
}

class SetNewPassword {
  const SetNewPassword(this._repository);

  static const minLength = 8;

  final OnboardingRepository _repository;

  Future<void> call({required String password, required String repeated}) {
    if (password.length < minLength ||
        !RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw const WeakPasswordFailure();
    }
    if (password != repeated) throw const PasswordMismatchFailure();
    return _repository.setPassword(password);
  }
}

class CompleteOnboarding {
  const CompleteOnboarding(this._repository);

  final OnboardingRepository _repository;

  Future<void> call({
    required PersonalData data,
    required String termsVersion,
    required bool termsAccepted,
  }) {
    if (!termsAccepted) throw const TermsNotAcceptedFailure();
    return _repository.complete(data: data, termsVersion: termsVersion);
  }
}
