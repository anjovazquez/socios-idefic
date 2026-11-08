import 'dart:typed_data';

import '../../domain/club/club_branding.dart';
import '../../domain/club/club_branding_repository.dart';

class GetClubBranding {
  const GetClubBranding(this._repository);

  final ClubBrandingRepository _repository;

  Future<ClubBranding> call(String clubId) => _repository.getBranding(clubId);
}

class SaveClubBranding {
  const SaveClubBranding(this._repository);

  final ClubBrandingRepository _repository;

  Future<void> call(ClubBranding branding) {
    final name = branding.name.trim();
    if (name.isEmpty) throw const InvalidBrandingFailure(BrandingField.name);
    final primary = normalizeHexColor(branding.primaryColor);
    if (primary == null) {
      throw const InvalidBrandingFailure(BrandingField.primaryColor);
    }
    final rawSecondary = branding.secondaryColor?.trim();
    final secondary = rawSecondary == null || rawSecondary.isEmpty
        ? null
        : normalizeHexColor(rawSecondary);
    if (rawSecondary != null && rawSecondary.isNotEmpty && secondary == null) {
      throw const InvalidBrandingFailure(BrandingField.secondaryColor);
    }
    return _repository.saveBranding(
      branding.copyWith(
        name: name,
        primaryColor: primary,
        secondaryColor: () => secondary,
      ),
    );
  }
}

class UploadClubAsset {
  const UploadClubAsset(this._repository);

  static const maxBytes = 2 * 1024 * 1024;
  static const allowedTypes = {'image/png', 'image/jpeg', 'image/webp'};

  final ClubBrandingRepository _repository;

  /// Returns the stored path and its public URL.
  Future<({String path, String url})> call({
    required String clubId,
    required ClubAssetKind kind,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty ||
        bytes.length > maxBytes ||
        !allowedTypes.contains(contentType)) {
      throw const InvalidAssetFailure();
    }
    final path = await _repository.uploadAsset(
      clubId: clubId,
      kind: kind,
      bytes: bytes,
      contentType: contentType,
    );
    return (path: path, url: _repository.publicUrl(path));
  }
}
