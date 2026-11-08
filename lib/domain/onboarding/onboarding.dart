/// Where a person stands in their first access (RF-003).
class OnboardingStatus {
  const OnboardingStatus({
    required this.completed,
    required this.needsPassword,
    required this.termsVersion,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.birthDate,
  });

  final bool completed;

  /// Invited by email and without Google: must create a password.
  final bool needsPassword;

  /// Version of the conditions to accept.
  final String termsVersion;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final DateTime? birthDate;
}

enum PersonalField { firstName, lastName, phone, birthDate }

/// Personal data asked in the first access (RF-003, RF-005).
class PersonalData {
  PersonalData._(this.firstName, this.lastName, this.phone, this.birthDate);

  /// Validates and normalizes; [today] keeps the check testable.
  factory PersonalData({
    required String firstName,
    required String lastName,
    String? phone,
    DateTime? birthDate,
    DateTime? today,
  }) {
    final first = firstName.trim();
    final last = lastName.trim();
    final normalizedPhone = phone?.replaceAll(RegExp(r'[\s.-]'), '');
    if (first.isEmpty) {
      throw const InvalidPersonalDataFailure(PersonalField.firstName);
    }
    if (last.isEmpty) {
      throw const InvalidPersonalDataFailure(PersonalField.lastName);
    }
    if (normalizedPhone != null &&
        normalizedPhone.isNotEmpty &&
        !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(normalizedPhone)) {
      throw const InvalidPersonalDataFailure(PersonalField.phone);
    }
    final now = today ?? DateTime.now();
    if (birthDate != null &&
        (birthDate.isAfter(DateTime(now.year, now.month, now.day)) ||
            birthDate.isBefore(DateTime(1900)))) {
      throw const InvalidPersonalDataFailure(PersonalField.birthDate);
    }
    return PersonalData._(
      first,
      last,
      normalizedPhone == null || normalizedPhone.isEmpty
          ? null
          : normalizedPhone,
      birthDate,
    );
  }

  final String firstName;
  final String lastName;
  final String? phone;
  final DateTime? birthDate;
}

sealed class OnboardingFailure implements Exception {
  const OnboardingFailure();
}

final class InvalidPersonalDataFailure extends OnboardingFailure {
  const InvalidPersonalDataFailure(this.field);

  final PersonalField field;
}

final class WeakPasswordFailure extends OnboardingFailure {
  const WeakPasswordFailure();
}

final class PasswordMismatchFailure extends OnboardingFailure {
  const PasswordMismatchFailure();
}

/// Invitation link used, replaced by a newer one or older than 24 h.
final class InvitationLinkExpiredFailure extends OnboardingFailure {
  const InvitationLinkExpiredFailure();
}

final class TermsNotAcceptedFailure extends OnboardingFailure {
  const TermsNotAcceptedFailure();
}

final class OnboardingUnavailableFailure extends OnboardingFailure {
  const OnboardingUnavailableFailure([this.cause]);

  final Object? cause;
}
