import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/club/club_branding.dart';
import '../../domain/club/club_branding_repository.dart';

class SupabaseClubBrandingRepository implements ClubBrandingRepository {
  const SupabaseClubBrandingRepository(this._client);

  static const bucket = 'club-assets';

  final SupabaseClient _client;

  @override
  Future<ClubBranding> getBranding(String clubId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_club_branding',
      params: {'p_club_id': clubId},
    );
    final row = rows.cast<Map<String, dynamic>>().single;
    return clubBrandingFromRow(row, publicUrl);
  });

  @override
  Future<void> saveBranding(ClubBranding branding) => _guard(
    () => _client.rpc<void>(
      'update_club_branding',
      params: {
        'p_club_id': branding.clubId,
        'p_name': branding.name,
        'p_primary_color': branding.primaryColor,
        'p_secondary_color': branding.secondaryColor,
        'p_logo_path': branding.logoPath,
        'p_image_path': branding.imagePath,
      },
    ),
  );

  @override
  Future<String> uploadAsset({
    required String clubId,
    required ClubAssetKind kind,
    required Uint8List bytes,
    required String contentType,
  }) => _guard(() async {
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    // A new name per upload so caches never serve the old logo.
    final path =
        '$clubId/${kind.name}-${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  });

  @override
  String publicUrl(String path) =>
      _client.storage.from(bucket).getPublicUrl(path);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapBrandingError(error.code, error.message);
    } on StorageException catch (error) {
      throw mapBrandingError(error.statusCode, error.message);
    } on BrandingFailure {
      rethrow;
    } catch (error) {
      throw BrandingUnavailableFailure(error);
    }
  }
}

ClubBranding clubBrandingFromRow(
  Map<String, dynamic> row,
  String Function(String path) publicUrl,
) {
  final logoPath = row['logo_path'] as String?;
  final imagePath = row['image_path'] as String?;
  return ClubBranding(
    clubId: row['club_id'] as String,
    name: row['name'] as String,
    primaryColor:
        row['primary_color'] as String? ?? ClubBranding.defaultPrimaryColor,
    secondaryColor: row['secondary_color'] as String?,
    logoPath: logoPath,
    imagePath: imagePath,
    logoUrl: logoPath == null ? null : publicUrl(logoPath),
    imageUrl: imagePath == null ? null : publicUrl(imagePath),
  );
}

BrandingFailure mapBrandingError(String? code, String message) {
  final text = message.toLowerCase();
  return switch (code) {
    '42501' || '403' => const BrandingPermissionFailure(),
    '22023' when text.contains('color') => const InvalidBrandingFailure(
      BrandingField.primaryColor,
    ),
    '22023' when text.contains('name') => const InvalidBrandingFailure(
      BrandingField.name,
    ),
    '22023' || '413' || '415' => const InvalidAssetFailure(),
    _ when text.contains('row-level security') =>
      const BrandingPermissionFailure(),
    _ => BrandingUnavailableFailure(message),
  };
}
