import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/perk/perk.dart';

class SupabasePerkRepository implements PerkRepository {
  const SupabasePerkRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Perk>> getClubPerks(String clubId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_club_perks',
      params: {'p_club_id': clubId},
    );
    return rows.cast<Map<String, dynamic>>().map(perkFromRow).toList();
  });

  @override
  Future<String> savePerk({
    String? perkId,
    required String clubId,
    String? sponsorId,
    required String title,
    required String body,
    String? imagePath,
    DateTime? validFrom,
    DateTime? validUntil,
    required bool publish,
  }) => _guard(
    () async => await _client.rpc<String>(
      'save_perk',
      params: {
        'p_perk_id': perkId,
        'p_club_id': clubId,
        'p_sponsor_id': sponsorId,
        'p_title': title,
        'p_body': body,
        'p_image_path': imagePath,
        'p_valid_from': _date(validFrom),
        'p_valid_until': _date(validUntil),
        'p_publish': publish,
      },
    ),
  );

  @override
  Future<void> setStatus(String perkId, PerkStatus status) => _guard(
    () => _client.rpc<void>(
      'set_perk_status',
      params: {'p_perk_id': perkId, 'p_status': status.name},
    ),
  );

  @override
  Future<List<Perk>> getMyPerks(String clubId) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_my_perks',
      params: {'p_club_id': clubId},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .map(
          (row) => myPerkFromRow(
            row,
            logoUrl: (path) =>
                _client.storage.from('club-assets').getPublicUrl(path),
          ),
        )
        .toList();
  });

  static String? _date(DateTime? value) =>
      value?.toIso8601String().substring(0, 10);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw mapPerkError(error.code, error.message);
    } on PerkFailure {
      rethrow;
    } catch (error) {
      throw PerkUnavailableFailure(error);
    }
  }
}

DateTime? _parseDate(Object? value) => switch (value) {
  final String text => DateTime.parse(text),
  _ => null,
};

Perk perkFromRow(Map<String, dynamic> row) => Perk(
  id: row['id'] as String,
  sponsorId: row['sponsor_id'] as String?,
  sponsorName: row['sponsor_name'] as String?,
  title: row['title'] as String,
  body: row['body'] as String,
  imagePath: row['image_path'] as String?,
  validFrom: _parseDate(row['valid_from']),
  validUntil: _parseDate(row['valid_until']),
  status: PerkStatus.values.byName(row['status'] as String),
);

PerkFailure mapPerkError(String? code, String message) => switch (code) {
  '42501' => const PerkPermissionFailure(),
  '22023' when message.contains('title') => const InvalidPerkFailure(
    PerkField.title,
  ),
  '22023' when message.contains('dates') => const InvalidPerkFailure(
    PerkField.dates,
  ),
  '22023' when message.contains('sponsor') => const InvalidPerkFailure(
    PerkField.sponsor,
  ),
  '22023' when message.contains('image') => const InvalidPerkFailure(
    PerkField.image,
  ),
  '22023' => const InvalidPerkFailure(PerkField.body),
  _ => PerkUnavailableFailure('$code $message'),
};

Perk myPerkFromRow(
  Map<String, dynamic> row, {
  required String Function(String path) logoUrl,
}) {
  final logoPath = row['sponsor_logo_path'] as String?;
  return Perk(
    id: row['id'] as String,
    title: row['title'] as String,
    body: row['body'] as String,
    status: PerkStatus.published,
    imagePath: row['image_path'] as String?,
    validFrom: _parseDate(row['valid_from']),
    validUntil: _parseDate(row['valid_until']),
    sponsorName: row['sponsor_name'] as String?,
    sponsorLogoUrl: logoPath == null ? null : logoUrl(logoPath),
    sponsorWebsiteUrl: row['sponsor_website_url'] as String?,
  );
}
