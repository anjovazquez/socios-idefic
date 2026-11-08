import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socios_idefic/application/club/club_branding_use_cases.dart';
import 'package:socios_idefic/domain/club/club_branding.dart';
import 'package:socios_idefic/domain/club/club_branding_repository.dart';

import '../support/fakes.dart';

void main() {
  late FakeClubBrandingRepository repository;

  setUp(() async {
    final auth = FakeAuthRepository(passwords: {'admin@example.com': 'pw'});
    await auth.signInWithPassword(email: 'admin@example.com', password: 'pw');
    final clubs = FakeClubRepository({
      'admin@example.com': [ideficAsAdmin],
    })..auth = auth;
    repository = FakeClubBrandingRepository(clubs);
  });

  ClubBranding branding({
    String name = 'IDEFIC',
    String primary = '#0b3d91',
    String? secondary,
  }) => ClubBranding(
    clubId: ideficAsAdmin.id,
    name: name,
    primaryColor: primary,
    secondaryColor: secondary,
  );

  test('normalizes colors and name before saving', () async {
    await SaveClubBranding(repository)(
      branding(name: '  IDEFIC Basket ', primary: '0b3d91', secondary: ' '),
    );

    expect(repository.lastSaved!.name, 'IDEFIC Basket');
    expect(repository.lastSaved!.primaryColor, '#0B3D91');
    expect(repository.lastSaved!.secondaryColor, isNull);
  });

  for (final (label, value, field) in [
    ('empty name', branding(name: ' '), BrandingField.name),
    ('bad primary', branding(primary: 'blue'), BrandingField.primaryColor),
    ('bad secondary', branding(secondary: '#12'), BrandingField.secondaryColor),
  ]) {
    test('rejects $label', () {
      expect(
        () => SaveClubBranding(repository)(value),
        throwsA(
          isA<InvalidBrandingFailure>().having((f) => f.field, 'field', field),
        ),
      );
    });
  }

  test('uploads valid images and returns their public URL', () async {
    final stored = await UploadClubAsset(repository)(
      clubId: ideficAsAdmin.id,
      kind: ClubAssetKind.logo,
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/png',
    );

    expect(stored.path, startsWith('${ideficAsAdmin.id}/logo'));
    expect(stored.url, 'https://cdn.test/${stored.path}');
  });

  test('rejects images that are too big or of another type', () {
    final upload = UploadClubAsset(repository);
    expect(
      () => upload(
        clubId: ideficAsAdmin.id,
        kind: ClubAssetKind.logo,
        bytes: Uint8List(UploadClubAsset.maxBytes + 1),
        contentType: 'image/png',
      ),
      throwsA(isA<InvalidAssetFailure>()),
    );
    expect(
      () => upload(
        clubId: ideficAsAdmin.id,
        kind: ClubAssetKind.logo,
        bytes: Uint8List(10),
        contentType: 'image/gif',
      ),
      throwsA(isA<InvalidAssetFailure>()),
    );
    expect(repository.uploads, 0);
  });
}
