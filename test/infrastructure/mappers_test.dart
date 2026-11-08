import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/auth/auth_failures.dart';
import 'package:socios_idefic/domain/club/club_branding.dart';
import 'package:socios_idefic/domain/club/my_club.dart';
import 'package:socios_idefic/domain/payment/payment.dart';
import 'package:socios_idefic/domain/platform/platform_failures.dart';
import 'package:socios_idefic/domain/season/season_membership.dart';
import 'package:socios_idefic/infrastructure/auth/supabase_auth_repository.dart';
import 'package:socios_idefic/infrastructure/club/my_club_mapper.dart';
import 'package:socios_idefic/infrastructure/club/supabase_club_branding_repository.dart';
import 'package:socios_idefic/infrastructure/payment/supabase_payments_repository.dart';
import 'package:socios_idefic/infrastructure/platform/supabase_platform_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps a get_my_clubs row', () {
    final club = myClubFromRow({
      'club_id': 'c1',
      'name': 'IDEFIC',
      'code': 'IDEFIC',
      'logo_path': null,
      'primary_color': '#0B3D91',
      'secondary_color': '#F2A900',
      'role': 'club_admin',
      'member_number': 3,
    });

    expect(club.id, 'c1');
    expect(club.role, ClubRole.clubAdmin);
    expect(club.memberNumber, 3);
    expect(club.primaryColor, '#0B3D91');
  });

  test('unknown roles default to member', () {
    final club = myClubFromRow({
      'club_id': 'c1',
      'name': 'IDEFIC',
      'code': 'IDEFIC',
      'role': 'member',
    });

    expect(club.role, ClubRole.member);
    expect(club.memberNumber, isNull);
  });

  test('maps Supabase invalid credentials', () {
    expect(
      mapAuthException(
        const AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      ),
      isA<InvalidCredentialsFailure>(),
    );
  });

  test('maps a rejected Google sign up to an unregistered account', () {
    expect(
      mapAuthException(
        const AuthException(
          'Signups not allowed for this instance',
          statusCode: '422',
          code: 'signup_disabled',
        ),
      ),
      isA<UnregisteredAccountFailure>(),
    );
    expect(
      mapAuthException(
        const AuthException('Signups not allowed for this instance'),
      ),
      isA<UnregisteredAccountFailure>(),
    );
  });

  test('maps other auth errors to unavailable', () {
    expect(
      mapAuthException(const AuthException('boom', statusCode: '500')),
      isA<AuthUnavailableFailure>(),
    );
  });

  test('platform admins enter clubs without membership', () {
    final club = myClubFromRow({
      'club_id': 'c1',
      'name': 'IDEFIC',
      'code': 'IDEFIC',
      'role': 'platform_admin',
    });

    expect(club.role, ClubRole.platformAdmin);
  });

  test('maps a get_platform_clubs row', () {
    final club = platformClubFromRow({
      'club_id': 'c1',
      'name': 'Club Nuevo',
      'code': 'NUEVO',
      'is_active': false,
      'member_count': 0,
      'admin_email': null,
      'pending_admin_email': 'nadie@test.com',
    });

    expect(club.isActive, isFalse);
    expect(club.pendingAdminEmail, 'nadie@test.com');
  });

  group('mapPlatformError', () {
    PlatformFailure map(String code, String message, {String? hint}) =>
        mapPlatformError(
          PostgrestException(message: message, code: code, hint: hint),
        );

    test('duplicate club code', () {
      expect(
        map(
          '23505',
          'duplicate key value violates unique constraint "clubs_code_key"',
        ),
        isA<DuplicateClubCodeFailure>(),
      );
    });

    test('second admin', () {
      expect(
        map(
          'P0001',
          'club already has an admin',
          hint: 'club_already_has_admin',
        ),
        isA<ClubAlreadyHasAdminFailure>(),
      );
      expect(
        map(
          '23505',
          'duplicate key value violates unique constraint "club_memberships_one_admin_idx"',
        ),
        isA<ClubAlreadyHasAdminFailure>(),
      );
    });

    test('permission', () {
      expect(
        map('42501', 'platform admin required'),
        isA<NotPlatformAdminFailure>(),
      );
    });

    test('invalid data', () {
      expect(
        map('22023', 'invalid admin email'),
        isA<InvalidClubDataFailure>().having(
          (f) => f.field,
          'field',
          ClubField.adminEmail,
        ),
      );
      expect(
        map('22023', 'invalid club code'),
        isA<InvalidClubDataFailure>().having(
          (f) => f.field,
          'field',
          ClubField.code,
        ),
      );
    });
  });

  test('resolves club asset URLs', () {
    final club = myClubFromRow({
      'club_id': 'c1',
      'name': 'IDEFIC',
      'code': 'IDEFIC',
      'role': 'member',
      'logo_path': 'c1/logo.png',
      'image_path': null,
    }, publicUrl: (path) => 'https://cdn/$path');

    expect(club.logoUrl, 'https://cdn/c1/logo.png');
    expect(club.imageUrl, isNull);
  });

  test('maps a branding row with the default color', () {
    final branding = clubBrandingFromRow({
      'club_id': 'c1',
      'name': 'IDEFIC',
      'primary_color': null,
      'secondary_color': '#F2A900',
      'logo_path': 'c1/logo.png',
      'image_path': null,
    }, (path) => 'https://cdn/$path');

    expect(branding.primaryColor, ClubBranding.defaultPrimaryColor);
    expect(branding.logoUrl, 'https://cdn/c1/logo.png');
  });

  test('maps branding errors', () {
    expect(
      mapBrandingError('42501', 'club admin required'),
      isA<BrandingPermissionFailure>(),
    );
    expect(
      mapBrandingError('403', 'new row violates row-level security policy'),
      isA<BrandingPermissionFailure>(),
    );
    expect(
      mapBrandingError('22023', 'invalid color'),
      isA<InvalidBrandingFailure>(),
    );
    expect(
      mapBrandingError('413', 'Payload too large'),
      isA<InvalidAssetFailure>(),
    );
  });

  test('maps an audit row', () {
    final entry = auditEntryFromRow({
      'id': 7,
      'club_id': 'c1',
      'club_name': 'IDEFIC',
      'actor_email': 'root@example.com',
      'as_platform_admin': true,
      'action': 'club_branding_updated',
      'payload': {'name': 'IDEFIC'},
      'created_at': '2026-11-08T12:00:00+00:00',
    });

    expect(entry.id, 7);
    expect(entry.asPlatformAdmin, isTrue);
    expect(entry.payload['name'], 'IDEFIC');
    expect(entry.createdAt.isUtc, isTrue);
  });

  test('maps get_my_subscription and get_my_payments rows', () {
    final subscription = mySubscriptionFromRow({
      'season_name': '2026/2027',
      'season_membership_id': 'sm1',
      'fee_cents': 5000,
      'status': 'pending_payment',
      'payment_provider': null,
      'payment_method': null,
      'next_charge_cents': null,
      'next_charge_on': null,
    });
    expect(subscription.status, SeasonMembershipStatus.pendingPayment);
    expect(subscription.canPay, isTrue);
    expect(subscription.lastMethod, isNull);

    final empty = mySubscriptionFromRow({
      'season_name': null,
      'season_membership_id': null,
      'fee_cents': null,
      'status': null,
    });
    expect(empty.hasSeason, isFalse);
    expect(empty.status, isNull);

    final payment = myPaymentFromRow({
      'payment_id': 'p1',
      'season_name': '2025/2026',
      'concept': 'Cuota de socio 2025/2026',
      'amount_cents': 4500,
      'payment_date': '2025-09-10T00:00:00+00:00',
      'status': 'paid',
      'provider': 'manual',
      'method': 'cash',
    });
    expect(payment.method, PaymentMethod.cash);
    expect(payment.status, PaymentStatus.paid);
    expect(payment.amountCents, 4500);
  });

  test('maps a get_receipt row with the member name or email', () {
    final row = {
      'payment_id': 'p1',
      'receipt_number': 3,
      'club_name': 'IDEFIC',
      'club_code': 'IDEFIC',
      'club_primary_color': '#0B3D91',
      'club_logo_path': null,
      'member_first_name': 'Ana',
      'member_last_name': 'Pérez',
      'member_email': 'ana@example.com',
      'member_number': 2,
      'season_name': '2026/2027',
      'concept': 'Cuota de socio 2026/2027',
      'amount_cents': 5000,
      'currency': 'EUR',
      'method': 'bizum',
      'paid_at': '2026-09-10T00:00:00+00:00',
    };
    final receipt = receiptFromRow(row, logoUrl: 'https://x/logo.png');
    expect(receipt.code, 'IDEFIC-0003');
    expect(receipt.memberName, 'Ana Pérez');
    expect(receipt.method, PaymentMethod.bizum);
    expect(receipt.clubLogoUrl, 'https://x/logo.png');

    final noName = receiptFromRow({
      ...row,
      'member_first_name': null,
      'member_last_name': null,
    });
    expect(noName.memberName, 'ana@example.com');
    expect(
      mapPaymentError('P0001', 'no receipt', 'no_receipt'),
      isA<NoReceiptFailure>(),
    );
  });
}
