import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/onboarding/onboarding.dart';
import '../../domain/onboarding/onboarding_repository.dart';

class SupabaseOnboardingRepository implements OnboardingRepository {
  const SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OnboardingStatus> getStatus() => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>('get_my_onboarding_status');
    return onboardingStatusFromRow(rows.cast<Map<String, dynamic>>().single);
  });

  @override
  Future<void> verifyInvitation({
    required String tokenHash,
    required String type,
  }) => _guard(
    () => _client.auth.verifyOTP(
      tokenHash: tokenHash,
      type: type == 'magiclink' ? OtpType.magiclink : OtpType.invite,
    ),
  );

  @override
  Future<void> setPassword(String password) => _guard(() async {
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
    } on AuthException catch (error) {
      // Coming back to the first access with the password already set.
      if (!isSamePasswordError(error)) rethrow;
    }
  });

  @override
  Future<void> complete({
    required PersonalData data,
    required String termsVersion,
  }) => _guard(
    () => _client.rpc<void>(
      'complete_onboarding',
      params: {
        'p_first_name': data.firstName,
        'p_last_name': data.lastName,
        'p_phone': data.phone,
        'p_birth_date': data.birthDate?.toIso8601String().substring(0, 10),
        'p_terms_version': termsVersion,
      },
    ),
  );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (error) {
      throw mapOnboardingAuthError(error);
    } on PostgrestException catch (error) {
      throw mapOnboardingDbError(error.code, error.message, error.hint);
    } on OnboardingFailure {
      rethrow;
    } catch (error) {
      throw OnboardingUnavailableFailure(error);
    }
  }
}

bool isSamePasswordError(AuthException error) =>
    error.code == 'same_password' ||
    error.message.toLowerCase().contains('should be different');

OnboardingStatus onboardingStatusFromRow(Map<String, dynamic> row) =>
    OnboardingStatus(
      completed: row['completed'] as bool? ?? false,
      needsPassword: row['needs_password'] as bool? ?? false,
      termsVersion: row['terms_version'] as String,
      email: row['email'] as String,
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      phone: row['phone'] as String?,
      birthDate: switch (row['birth_date']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
    );

OnboardingFailure mapOnboardingAuthError(AuthException error) =>
    switch (error.code) {
      'otp_expired' ||
      'invalid_credentials' ||
      'bad_jwt' => const InvitationLinkExpiredFailure(),
      'weak_password' => const WeakPasswordFailure(),
      _ when error.message.toLowerCase().contains('expired') =>
        const InvitationLinkExpiredFailure(),
      _ => OnboardingUnavailableFailure(error),
    };

OnboardingFailure mapOnboardingDbError(
  String? code,
  String message,
  String? hint,
) => switch (code) {
  '22023' when message.contains('first name') =>
    const InvalidPersonalDataFailure(PersonalField.firstName),
  '22023' when message.contains('last name') =>
    const InvalidPersonalDataFailure(PersonalField.lastName),
  '22023' when message.contains('phone') => const InvalidPersonalDataFailure(
    PersonalField.phone,
  ),
  '22023' when message.contains('birth') => const InvalidPersonalDataFailure(
    PersonalField.birthDate,
  ),
  'P0001' when hint == 'terms_outdated' => const TermsNotAcceptedFailure(),
  _ => OnboardingUnavailableFailure('$code $message'),
};
