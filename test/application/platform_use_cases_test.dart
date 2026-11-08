import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/platform/platform_use_cases.dart';
import 'package:socios_idefic/domain/platform/platform_failures.dart';

import '../support/fakes.dart';

void main() {
  late FakePlatformRepository platform;

  setUp(() async {
    final auth = FakeAuthRepository(passwords: {'root@example.com': 'pw'});
    await auth.signInWithPassword(email: 'root@example.com', password: 'pw');
    platform = FakePlatformRepository(
      adminEmails: {'root@example.com'},
      existingUsers: {'admin@cou.es'},
    )..auth = auth;
  });

  test('CreateClub normalizes code and admin email', () async {
    await CreateClub(platform)(
      name: '  Club Ourense ',
      code: ' cou ',
      adminEmail: ' Admin@COU.es ',
      adminName: '  ',
    );

    final club = platform.clubs.single;
    expect(club.name, 'Club Ourense');
    expect(club.code, 'COU');
    expect(club.adminEmail, 'admin@cou.es');
  });

  for (final (label, name, code, email, field) in [
    ('empty name', ' ', 'COU', 'a@b.es', ClubField.name),
    ('short code', 'Club', 'C', 'a@b.es', ClubField.code),
    ('code with symbols', 'Club', 'C*U', 'a@b.es', ClubField.code),
    ('bad email', 'Club', 'COU', 'admin', ClubField.adminEmail),
  ]) {
    test('CreateClub rejects $label before calling the server', () {
      expect(
        () => CreateClub(platform)(name: name, code: code, adminEmail: email),
        throwsA(
          isA<InvalidClubDataFailure>().having((f) => f.field, 'field', field),
        ),
      );
      expect(platform.clubs, isEmpty);
    });
  }

  test('UpdateClub validates too', () {
    expect(
      () => UpdateClub(platform)(clubId: 'x', name: '', code: 'COU'),
      throwsA(isA<InvalidClubDataFailure>()),
    );
  });
}
