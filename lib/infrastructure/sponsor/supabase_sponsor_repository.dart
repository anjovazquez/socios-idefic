import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/sponsor/sponsor.dart';

class SupabaseSponsorRepository implements SponsorRepository {
  const SupabaseSponsorRepository(this._client);

  final SupabaseClient _client;

  /// Sponsor logos are brand material: public bucket of the club (D-017).
  static const bucket = 'club-assets';

  @override
  Future<List<Sponsor>> getClubSponsors(String clubId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_club_sponsors',
      params: {'p_club_id': clubId},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => sponsorFromRow(row, logoUrl: logoUrl))
        .toList();
  });

  @override
  Future<String> saveSponsor({
    String? sponsorId,
    required String clubId,
    required String name,
    String? logoPath,
    String? websiteUrl,
  }) => _guard(
    () async => await _client.rpc<String>(
      'save_sponsor',
      params: {
        'p_sponsor_id': sponsorId,
        'p_club_id': clubId,
        'p_name': name,
        'p_logo_path': logoPath,
        'p_website_url': websiteUrl,
      },
    ),
  );

  @override
  Future<void> setActive(String sponsorId, bool active) => _guard(
    () => _client.rpc<void>(
      'set_sponsor_active',
      params: {'p_sponsor_id': sponsorId, 'p_active': active},
    ),
  );

  @override
  Future<void> setSeasons(String sponsorId, List<String> seasonIds) => _guard(
    () => _client.rpc<void>(
      'set_sponsor_seasons',
      params: {'p_sponsor_id': sponsorId, 'p_season_ids': seasonIds},
    ),
  );

  @override
  Future<int> renew(String seasonId, List<String> sponsorIds) => _guard(
    () async => await _client.rpc<int>(
      'renew_sponsors',
      params: {'p_season_id': seasonId, 'p_sponsor_ids': sponsorIds},
    ),
  );

  @override
  Future<String> uploadLogo({
    required String clubId,
    required Uint8List bytes,
    required String contentType,
  }) => _guard(() async {
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        '$clubId/sponsor-${DateTime.now().millisecondsSinceEpoch}.$extension';
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
  String logoUrl(String path) =>
      _client.storage.from(bucket).getPublicUrl(path);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapSponsorError(error.code, error.message);
    } on StorageException catch (error) {
      throw mapSponsorError(error.statusCode, error.message);
    } on SponsorFailure {
      rethrow;
    } catch (error) {
      throw SponsorUnavailableFailure(error);
    }
  }
}

Sponsor sponsorFromRow(
  Map<String, dynamic> row, {
  String Function(String path)? logoUrl,
}) {
  final logoPath = row['logo_path'] as String?;
  return Sponsor(
    id: row['id'] as String,
    name: row['name'] as String,
    logoPath: logoPath,
    logoUrl: logoPath == null ? null : logoUrl?.call(logoPath),
    websiteUrl: row['website_url'] as String?,
    isActive: row['is_active'] as bool? ?? true,
    seasonIds: [...?(row['season_ids'] as List?)?.cast<String>()],
    seasonNames: [...?(row['season_names'] as List?)?.cast<String>()],
  );
}

SponsorFailure mapSponsorError(String? code, String message) => switch (code) {
  '42501' || '403' => const SponsorPermissionFailure(),
  '23505' => const SponsorAlreadyExistsFailure(),
  '22023' when message.contains('website') => const InvalidSponsorFailure(
    SponsorField.website,
  ),
  '22023' when message.contains('logo') => const InvalidSponsorFailure(
    SponsorField.logo,
  ),
  '22023'
      when message.contains('season') ||
          message.contains('sponsor of another') =>
    const InvalidSponsorFailure(SponsorField.seasons),
  '22023' => const InvalidSponsorFailure(SponsorField.name),
  _ => SponsorUnavailableFailure('$code $message'),
};
