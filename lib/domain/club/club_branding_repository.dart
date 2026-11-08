import 'dart:typed_data';

import 'club_branding.dart';

enum ClubAssetKind { logo, image }

abstract interface class ClubBrandingRepository {
  Future<ClubBranding> getBranding(String clubId);

  Future<void> saveBranding(ClubBranding branding);

  /// Stores the image in the club folder and returns its storage path.
  Future<String> uploadAsset({
    required String clubId,
    required ClubAssetKind kind,
    required Uint8List bytes,
    required String contentType,
  });

  String publicUrl(String path);
}
