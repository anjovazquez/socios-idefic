import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/domain/auth/auth_failures.dart';
import 'package:socios_idefic/domain/club/my_club.dart';
import 'package:socios_idefic/infrastructure/auth/supabase_auth_repository.dart';
import 'package:socios_idefic/infrastructure/club/my_club_mapper.dart';
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
}
