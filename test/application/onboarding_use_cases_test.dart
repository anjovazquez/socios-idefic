import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/onboarding/onboarding_use_cases.dart';
import 'package:socios_idefic/domain/onboarding/onboarding.dart';
import 'package:socios_idefic/infrastructure/onboarding/supabase_onboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fakes.dart';

void main() {
  group('PersonalData', () {
    final today = DateTime(2026, 11, 8);

    test('normalizes the values', () {
      final data = PersonalData(
        firstName: ' Marta ',
        lastName: ' Gómez ',
        phone: '600 11-22.33',
        birthDate: DateTime(1990, 5, 1),
        today: today,
      );
      expect(data.firstName, 'Marta');
      expect(data.lastName, 'Gómez');
      expect(data.phone, '600112233');
    });

    test('phone and birth date are optional', () {
      final data = PersonalData(firstName: 'M', lastName: 'G', phone: ' ');
      expect(data.phone, isNull);
      expect(data.birthDate, isNull);
    });

    for (final (label, build, field) in [
      (
        'no first name',
        () => PersonalData(firstName: ' ', lastName: 'G'),
        PersonalField.firstName,
      ),
      (
        'no last name',
        () => PersonalData(firstName: 'M', lastName: ''),
        PersonalField.lastName,
      ),
      (
        'short phone',
        () => PersonalData(firstName: 'M', lastName: 'G', phone: '123'),
        PersonalField.phone,
      ),
      (
        'future birth date',
        () => PersonalData(
          firstName: 'M',
          lastName: 'G',
          birthDate: DateTime(2026, 11, 9),
          today: today,
        ),
        PersonalField.birthDate,
      ),
    ]) {
      test('rejects $label', () {
        expect(
          build,
          throwsA(
            isA<InvalidPersonalDataFailure>().having(
              (f) => f.field,
              'field',
              field,
            ),
          ),
        );
      });
    }
  });

  group('SetNewPassword', () {
    late FakeOnboardingRepository repository;

    setUp(() async {
      final auth = FakeAuthRepository(passwords: {'marta@example.com': 'x'});
      await auth.signInWithPassword(email: 'marta@example.com', password: 'x');
      repository = FakeOnboardingRepository()..auth = auth;
    });

    test('requires 8 characters with letters and numbers', () {
      for (final weak in ['abc12', 'abcdefgh', '12345678']) {
        expect(
          () => SetNewPassword(repository)(password: weak, repeated: weak),
          throwsA(isA<WeakPasswordFailure>()),
        );
      }
    });

    test('requires both fields to match', () {
      expect(
        () => SetNewPassword(repository)(
          password: 'secreto123',
          repeated: 'secreto124',
        ),
        throwsA(isA<PasswordMismatchFailure>()),
      );
    });

    test('saves a valid password', () async {
      await SetNewPassword(repository)(
        password: 'secreto123',
        repeated: 'secreto123',
      );
      expect(repository.passwords['marta@example.com'], 'secreto123');
    });
  });

  test('a link without token or with another type is not valid', () {
    final repository = FakeOnboardingRepository();
    expect(
      () => VerifyInvitationLink(repository)(tokenHash: null, type: 'invite'),
      throwsA(isA<InvitationLinkExpiredFailure>()),
    );
    expect(
      () => VerifyInvitationLink(repository)(tokenHash: 'x', type: 'recovery'),
      throwsA(isA<InvitationLinkExpiredFailure>()),
    );
  });

  test('conditions must be accepted', () {
    expect(
      () => CompleteOnboarding(FakeOnboardingRepository())(
        data: PersonalData(firstName: 'M', lastName: 'G'),
        termsVersion: 'v1',
        termsAccepted: false,
      ),
      throwsA(isA<TermsNotAcceptedFailure>()),
    );
  });

  test('maps the onboarding status row', () {
    final status = onboardingStatusFromRow({
      'completed': false,
      'needs_password': true,
      'terms_version': '2026-11-v1',
      'email': 'marta@example.com',
      'first_name': 'Marta',
      'last_name': null,
      'phone': null,
      'birth_date': '1990-05-01',
    });
    expect(status.needsPassword, isTrue);
    expect(status.birthDate, DateTime(1990, 5, 1));
  });

  test('maps auth and database errors', () {
    expect(
      mapOnboardingAuthError(
        const AuthException(
          'Email link is invalid or has expired',
          code: 'otp_expired',
        ),
      ),
      isA<InvitationLinkExpiredFailure>(),
    );
    expect(
      mapOnboardingAuthError(
        const AuthException('weak', code: 'weak_password'),
      ),
      isA<WeakPasswordFailure>(),
    );
    expect(
      mapOnboardingDbError('22023', 'invalid phone', null),
      isA<InvalidPersonalDataFailure>(),
    );
    expect(
      mapOnboardingDbError('P0001', 'terms not accepted', 'terms_outdated'),
      isA<TermsNotAcceptedFailure>(),
    );
  });

  test('re-entering the same password is not an error', () {
    expect(
      isSamePasswordError(
        const AuthException(
          'New password should be different from the old password.',
          code: 'same_password',
        ),
      ),
      isTrue,
    );
    expect(
      isSamePasswordError(const AuthException('weak', code: 'weak_password')),
      isFalse,
    );
  });
}
