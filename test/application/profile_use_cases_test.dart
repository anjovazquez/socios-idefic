import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/profile/profile_use_cases.dart';
import 'package:socios_idefic/domain/onboarding/onboarding.dart';
import 'package:socios_idefic/domain/profile/my_profile.dart';
import 'package:socios_idefic/infrastructure/profile/supabase_profile_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeProfileRepository repository;

  setUp(() async {
    final auth = FakeAuthRepository(passwords: {'ana@example.com': 'pw'});
    await auth.signInWithPassword(email: 'ana@example.com', password: 'pw');
    repository = FakeProfileRepository()..auth = auth;
  });

  test('saves validated data for the signed-in person only', () async {
    await UpdateMyProfile(repository)(
      firstName: ' Ana ',
      lastName: 'Pérez',
      phone: '600-11-22-33',
    );

    final profile = repository.profiles['ana@example.com']!;
    expect(profile.firstName, 'Ana');
    expect(profile.phone, '600112233');
    expect(repository.profiles.keys, ['ana@example.com']);
  });

  test('a future birth date is rejected', () {
    expect(
      () => UpdateMyProfile(repository)(
        firstName: 'Ana',
        lastName: 'Pérez',
        birthDate: DateTime.now().add(const Duration(days: 2)),
      ),
      throwsA(
        isA<InvalidPersonalDataFailure>().having(
          (f) => f.field,
          'field',
          PersonalField.birthDate,
        ),
      ),
    );
  });

  test('photos must be small images', () {
    final upload = UploadProfilePhoto(repository);
    expect(
      () => upload(
        bytes: Uint8List(UploadProfilePhoto.maxBytes + 1),
        contentType: 'image/jpeg',
      ),
      throwsA(isA<InvalidPhotoFailure>()),
    );
    expect(
      () => upload(bytes: Uint8List(10), contentType: 'application/pdf'),
      throwsA(isA<InvalidPhotoFailure>()),
    );
    expect(repository.uploads, 0);
  });

  test('maps the profile row', () {
    final profile = myProfileFromRow({
      'email': 'ana@example.com',
      'first_name': 'Ana',
      'last_name': 'Pérez',
      'phone': null,
      'birth_date': '1990-01-31',
      'photo_path': 'u1/photo.jpg',
    }, photoUrl: 'https://signed/u1/photo.jpg');

    expect(profile.birthDate, DateTime(1990, 1, 31));
    expect(profile.photoUrl, 'https://signed/u1/photo.jpg');
  });
}
